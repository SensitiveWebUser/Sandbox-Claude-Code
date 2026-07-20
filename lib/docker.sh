# shellcheck shell=bash
# scc — source-available under PolyForm Noncommercial 1.0.0; see LICENSE.
#
# lib/docker.sh — assemble the hardened `docker run` argument list and run it.
#
# These functions read globals the dispatcher (scc) sets before calling them:
#   IMAGE, VOLUME, PIDS_LIMIT, EXTRA_DOMAINS, EXTRA_DOCKER_ARGS, SCC_BUILD_DIR
# shellcheck disable=SC2154

# Build the image from the resolved build context.
scc_build() {
  [[ -f "$SCC_BUILD_DIR/Dockerfile" ]] \
    || scc_die "no Dockerfile in $SCC_BUILD_DIR — run install.sh or set SCC_DIR"
  docker build --pull -t "$IMAGE" "$SCC_BUILD_DIR"
}

# Make sure $IMAGE is available locally.
#   * already present            -> nothing to do
#   * namespaced/registry image  -> pull it (e.g. ghcr.io/owner/scc:tag),
#                                   falling back to a local build if the pull
#                                   fails but a Dockerfile is available
#   * bare local tag (scc:latest)-> build it
# The "*/*" heuristic means a bare registry name (e.g. "ubuntu") would be built
# rather than pulled — irrelevant here, since scc images are always namespaced.
scc_ensure_image() {
  docker image inspect "$IMAGE" >/dev/null 2>&1 && return 0
  if [[ "$IMAGE" == */* ]]; then
    scc_info "pulling image $IMAGE ..."
    docker pull "$IMAGE" && return 0
    [[ -f "$SCC_BUILD_DIR/Dockerfile" ]] \
      || scc_die "could not pull $IMAGE and no Dockerfile to build from"
    scc_warn "pull failed; building $IMAGE locally instead"
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
  if [[ -n "$EXTRA_DOCKER_ARGS" ]]; then
    # Intentional word splitting for user-supplied extra args.
    # shellcheck disable=SC2206
    ARGS+=($EXTRA_DOCKER_ARGS)
  fi
}

# Mount ONLY the current directory, at the same absolute path as on the host.
scc_workspace_args() {
  ARGS+=(-v "$PWD:$PWD" -w "$PWD")
  if [[ -f "$HOME/.gitconfig" ]]; then
    ARGS+=(-v "$HOME/.gitconfig:/home/node/.gitconfig:ro")
  fi
  # No signing keys are mounted, so disable commit signing to keep commits from
  # failing for users who sign by default. (Opt-in signing arrives in M2.)
  ARGS+=(-e GIT_CONFIG_COUNT=1
         -e GIT_CONFIG_KEY_0=commit.gpgsign -e GIT_CONFIG_VALUE_0=false)
}

# Assemble and exec a workspace run. $1 = mode (firewall|open); rest = command.
scc_run_in_workspace() {
  local mode="$1"; shift
  scc_guard_workdir
  scc_ensure_image
  scc_base_args "$mode"
  scc_workspace_args
  exec docker run "${ARGS[@]}" "$IMAGE" "$@"
}
