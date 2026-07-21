# shellcheck shell=bash
# scc: source-available under PolyForm Noncommercial 1.0.0 (see LICENSE).
#
# lib/docker.sh: assemble the hardened `docker run` args and run it.
# Reads globals set by the dispatcher (IMAGE, VOLUME, PIDS_LIMIT, EXTRA_*,
# SCC_BUILD_DIR), hence SC2154 is silenced.
# shellcheck disable=SC2154

# Build the image from the resolved build context.
scc_build() {
  [[ -f "$SCC_BUILD_DIR/Dockerfile" ]] \
    || scc_die "no Dockerfile in $SCC_BUILD_DIR: run install.sh or set SCC_DIR"
  docker build --pull -t "$IMAGE" "$SCC_BUILD_DIR"
}

# Ensure $IMAGE is available: present -> noop, namespaced (a/b) -> pull (fall
# back to build), bare tag (scc:latest) -> build.
scc_ensure_image() {
  docker image inspect "$IMAGE" >/dev/null 2>&1 && return 0
  if [[ "$IMAGE" == */* ]]; then
    scc_info "pulling image $IMAGE ..."
    docker pull "$IMAGE" && return 0
    [[ -f "$SCC_BUILD_DIR/Dockerfile" ]] \
      || scc_die "could not pull $IMAGE and no Dockerfile to build from"
    scc_warn "pull failed, building $IMAGE locally instead"
  fi
  scc_build
}

# Common, hardened args into the global ARGS array. $1 = firewall|open.
scc_base_args() {
  ARGS=(
    --rm --init
    --hostname scc
    --security-opt no-new-privileges:true
    --cap-drop ALL
    --cap-add CHOWN --cap-add DAC_OVERRIDE --cap-add FOWNER
    --cap-add SETUID --cap-add SETGID --cap-add KILL
    --pids-limit "$PIDS_LIMIT"
    -e "HOST_UID=$(id -u)" -e "HOST_GID=$(id -g)"
    -e TERM -e COLORTERM
    -e CLAUDE_CODE_OAUTH_TOKEN
    -v "$VOLUME:/home/node"
  )
  if [[ -t 0 ]]; then ARGS+=(-it); else ARGS+=(-i); fi
  if [[ "$1" == "firewall" ]]; then
    ARGS+=(-e SCC_FIREWALL=1 -e "FIREWALL_EXTRA_DOMAINS=$EXTRA_DOMAINS"
           --cap-add NET_ADMIN --cap-add NET_RAW)
  fi
  # --hardened: read-only rootfs + writable tmpfs only. The entrypoint detects
  # the read-only /etc and remaps via numeric uid:gid instead of editing passwd.
  if [[ "${SCC_HARDENED:-0}" == 1 ]]; then
    ARGS+=(--read-only
           --tmpfs "/tmp:rw,nosuid,nodev,noexec"
           --tmpfs "/var/tmp:rw,nosuid,nodev"
           --tmpfs "/run:rw,nosuid,nodev")
  fi
  # Pass the gh token by name (set by the gh toolchain), never as an argv value.
  if [[ "${SCC_GH_TOKEN:-0}" == 1 ]]; then
    ARGS+=(-e GH_TOKEN)
  fi
  if [[ -n "$EXTRA_DOCKER_ARGS" ]]; then
    # Intentional word splitting for user-supplied extra args.
    # shellcheck disable=SC2206
    ARGS+=($EXTRA_DOCKER_ARGS)
  fi
}

# --ssh-agent: forward the SSH agent so in-sandbox git can sign commits and
# push. The private key never enters the container. The agent (on the host)
# performs the signing.
scc_ssh_agent_args() {
  [[ -n "${SSH_AUTH_SOCK:-}" && -S "$SSH_AUTH_SOCK" ]] \
    || scc_die "--ssh-agent needs a running SSH agent (SSH_AUTH_SOCK unset or not a socket). Start one and 'ssh-add' your key."
  scc_info "--ssh-agent: forwarding your SSH agent for commit signing and push (key stays on the host)"
  ARGS+=(-v "$SSH_AUTH_SOCK:/run/scc-ssh-agent" -e SSH_AUTH_SOCK=/run/scc-ssh-agent)
  # SSH commit signing needs the public key file present. Mount only the public
  # key (not secret). The agent holds the private half.
  if [[ "$(git config --get gpg.format 2>/dev/null)" == "ssh" ]]; then
    local key; key="$(git config --get user.signingkey 2>/dev/null || true)"
    if [[ -n "$key" && -f "$key" ]]; then
      ARGS+=(-v "$key:$key:ro")
    elif [[ -n "$key" ]]; then
      scc_warn "user.signingkey '$key' is not a readable file, so commit signing may fail in the sandbox"
    fi
  fi
}

# Clipboard forwarding for in-chat image paste. Default (auto) forwards the host
# Wayland clipboard socket when present, a no-op on non-Wayland hosts. X11 is
# forwarded only on explicit request (it has no isolation between clients).
# --hardened turns the auto behavior off. Every mount is guarded by an existence
# check, so a normal run never fails because of this.
scc_clipboard_args() {
  local mode; mode="$(scc_resolve clipboard SCC_CLIPBOARD auto)"
  if [[ "$mode" == auto && "${SCC_HARDENED:-0}" == 1 ]]; then mode=off; fi
  [[ "$mode" == off ]] && return 0

  if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
    local wl="$WAYLAND_DISPLAY"
    [[ "$wl" == /* ]] || wl="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/$wl"
    if [[ -S "$wl" ]]; then
      ARGS+=(-v "$wl:/tmp/scc-wayland.sock" -e WAYLAND_DISPLAY=/tmp/scc-wayland.sock)
      scc_info "clipboard: forwarding the Wayland clipboard for image paste"
      return 0
    fi
  fi
  if [[ "$mode" == on && -n "${DISPLAY:-}" && -d /tmp/.X11-unix ]]; then
    ARGS+=(-v /tmp/.X11-unix:/tmp/.X11-unix:ro -e "DISPLAY=$DISPLAY")
    scc_warn "clipboard: forwarding X11 for paste (X11 has no isolation between clients)"
    return 0
  fi
  [[ "$mode" == on ]] && scc_warn "clipboard: no host Wayland/X11 clipboard socket found to forward"
  return 0
}

# --screenshots[=DIR]: mount a screenshots/inbox directory read-only so images
# outside the repo can be referenced. Default dir is the OS screenshot location.
scc_screenshots_args() {
  [[ -n "${SCC_SCREENSHOTS:-}" ]] || return 0
  local dir="$SCC_SCREENSHOTS"
  if [[ "$dir" == __default__ ]]; then
    case "$(uname -s)" in
      Darwin) dir="$HOME/Desktop" ;;
      *)      dir="$HOME/Pictures" ;;
    esac
  fi
  dir="${dir/#\~/$HOME}"
  if [[ -d "$dir" ]]; then
    ARGS+=(-v "$dir:$dir:ro")
    scc_info "screenshots: mounting $dir read-only for image references"
  else
    scc_warn "screenshots: directory '$dir' not found, not mounting it"
  fi
}

# Mount ONLY the current directory, at the same absolute path as on the host.
scc_workspace_args() {
  ARGS+=(-v "$PWD:$PWD" -w "$PWD")
  if [[ -f "$HOME/.gitconfig" ]]; then
    ARGS+=(-v "$HOME/.gitconfig:/home/node/.gitconfig:ro")
  fi
  if [[ "${SCC_SSH_AGENT:-0}" == 1 ]]; then
    scc_ssh_agent_args
  else
    # No signing keys in the sandbox: disable signing so signed-by-default
    # commits don't fail. Enable real signing with --ssh-agent.
    ARGS+=(-e GIT_CONFIG_COUNT=1
           -e GIT_CONFIG_KEY_0=commit.gpgsign -e GIT_CONFIG_VALUE_0=false)
  fi
  scc_clipboard_args
  scc_screenshots_args
}

# Assemble and exec a workspace run. $1 = mode (firewall|open), rest = command.
scc_run_in_workspace() {
  local mode="$1"; shift
  scc_guard_workdir
  scc_ensure_image
  scc_base_args "$mode"
  scc_workspace_args
  exec docker run "${ARGS[@]}" "$IMAGE" "$@"
}
