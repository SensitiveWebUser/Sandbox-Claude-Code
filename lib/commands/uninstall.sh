# shellcheck shell=bash
# scc: source-available under PolyForm Noncommercial 1.0.0 (see LICENSE).
# lib/commands/uninstall.sh: remove scc. Safe by default: only the launcher and
# build dir. Config/volume/image removed only when explicitly requested.
# SCC_DIR/VOLUME/IMAGE/SCC_CONFIG_FILE come from the dispatcher, hence SC2154.
# shellcheck disable=SC2154

cmd_uninstall() {
  # Resolve the installed launcher via PATH (finds a custom BIN_DIR install,
  # since it must be on PATH to be runnable). Fall back to the default dir.
  local launcher
  launcher="$(command -v scc 2>/dev/null || true)"
  [[ -n "$launcher" ]] || launcher="${BIN_DIR:-$HOME/.local/bin}/scc"
  local rm_volume=0 rm_image=0 rm_config=0 assume_yes=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --volume)  rm_volume=1 ;;
      --image)   rm_image=1 ;;
      --config)  rm_config=1 ;;
      --all)     rm_volume=1; rm_image=1; rm_config=1 ;;
      -y|--yes)  assume_yes=1 ;;
      -h|--help)
        cat <<'EOF'
scc uninstall: remove scc from this machine

  scc uninstall            Remove the launcher and build dir (~/.scc)
  scc uninstall --config   Also remove the config file
  scc uninstall --volume   Also remove the home volume (login + Claude install!)
  scc uninstall --image    Also remove the Docker image
  scc uninstall --all      Remove everything above
  scc uninstall -y|--yes   Do not prompt for confirmation
EOF
        return 0 ;;
      *) scc_die "uninstall: unknown option '$1' (try: scc uninstall --help)" ;;
    esac
    shift
  done

  local safe_dir=0
  [[ -d "$SCC_DIR" ]] && scc_dir_is_scc_install "$SCC_DIR" && safe_dir=1

  scc_heading "scc uninstall: the following will be removed:"
  if [[ -e "$launcher" ]]; then
    echo "  launcher:  $launcher"
  else
    scc_warn "launcher not found (looked for $launcher). If installed to a custom path, remove it manually"
  fi
  if [[ -d "$SCC_DIR" ]]; then
    if (( safe_dir )); then echo "  build dir: $SCC_DIR"
    else scc_warn "will NOT remove $SCC_DIR (it is \$HOME/ or does not look like an scc install); remove it by hand if intended"; fi
  fi
  if (( rm_config )); then [[ -e "$SCC_CONFIG_FILE" ]] && echo "  config:    $SCC_CONFIG_FILE"; fi
  if (( rm_volume )); then echo "  volume:    $VOLUME  (your login + Claude Code install, so you must log in again)"; fi
  if (( rm_image ));  then echo "  image:     $IMAGE"; fi
  echo
  scc_dim "Kept unless requested: config (--config), home volume (--volume), image (--image)."
  echo

  if (( ! assume_yes )); then
    printf 'scc: proceed? [y/N] ' >&2
    local reply=""
    read -r reply || true
    case "$reply" in
      y|Y|yes|YES) ;;
      *) scc_die "aborted. Nothing was removed." ;;
    esac
  fi

  rm -f "$launcher"
  (( safe_dir )) && rm -rf "${SCC_DIR:?}"
  (( rm_config )) && rm -f "$SCC_CONFIG_FILE"

  if (( rm_volume || rm_image )); then
    if scc_has docker; then
      (( rm_volume )) && docker volume rm "$VOLUME" >/dev/null 2>&1 \
        && scc_info "removed volume $VOLUME"
      if (( rm_image )); then
        docker image rm "$IMAGE" >/dev/null 2>&1 && scc_info "removed image $IMAGE"
        # Also drop cached toolchain variants (<repo>:tc-*), else --all leaves
        # multi-GB layers behind. Strip only a real tag (last path segment).
        local repo_ref="$IMAGE" v
        [[ "${repo_ref##*/}" == *:* ]] && repo_ref="${repo_ref%:*}"
        while IFS= read -r v; do
          [[ -n "$v" ]] || continue
          docker image rm "$v" >/dev/null 2>&1 && scc_info "removed image $v"
        done < <(docker image ls --filter "reference=$repo_ref:tc-*" --format '{{.Repository}}:{{.Tag}}' 2>/dev/null)
      fi
    else
      scc_warn "docker not found: skipped removing the volume/image."
    fi
  fi

  scc_info "scc removed. Thanks for trying it."
}
