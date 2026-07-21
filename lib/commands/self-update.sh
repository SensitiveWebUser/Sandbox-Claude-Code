# shellcheck shell=bash
# scc: source-available under PolyForm Noncommercial 1.0.0 (see LICENSE).
# lib/commands/self-update.sh: update scc itself to the latest GitHub release.
# (`scc update` updates Claude Code inside the sandbox; this updates scc.)
# IMAGE / SCC_VERSION_STR are set by the dispatcher.
# shellcheck disable=SC2154

# Resolve the latest release tag of a repo via the GitHub API (no jq).
scc_selfupdate_latest_tag() {  # $1=owner/repo  -> echoes vX.Y.Z
  curl -fsSL "https://api.github.com/repos/$1/releases/latest" \
    | grep -m1 '"tag_name"' | cut -d'"' -f4
}

# After the launcher is updated, refresh the image so image-side fixes
# (entrypoint, firewall, Dockerfile) actually take effect. A registry image is
# pulled; a locally-built one is left for the user to `scc rebuild`.
scc_selfupdate_refresh_image() {
  scc_has docker || { scc_info "install docker, then run 'scc rebuild' to refresh the image"; return 0; }
  if [[ "$IMAGE" == */* ]]; then
    scc_info "refreshing the image ($IMAGE) ..."
    docker pull "$IMAGE" >/dev/null 2>&1 \
      && scc_info "image up to date." \
      || scc_warn "could not pull $IMAGE now, it will be pulled on the next run"
  else
    scc_info "run 'scc rebuild' to rebuild the local image ($IMAGE) with any image-side changes"
  fi
}

cmd_self_update() {
  local check=0 assume_yes=0 force=0 a
  for a in "$@"; do
    case "$a" in
      --check)     check=1 ;;
      -y|--yes)    assume_yes=1 ;;
      --force)     force=1 ;;
      -h|--help)
        cat <<'EOF'
scc self-update: update scc itself to the latest GitHub release

  scc self-update            Update to the latest release (prompts to confirm)
  scc self-update --check    Show installed vs latest, do not change anything
  scc self-update -y         Update without the confirmation prompt
  scc self-update --force    Reinstall even if already on the latest version

  SCC_VERSION=vX.Y.Z         Pin a specific release instead of latest
  SCC_REPO=owner/repo        Update from a fork
EOF
        return 0 ;;
      *) scc_die "self-update: unknown option '$a' (try --check, -y, --force, --help)" ;;
    esac
  done

  scc_has curl || scc_die "self-update needs curl on the host"
  scc_has tar  || scc_die "self-update needs tar on the host"

  local repo="${SCC_REPO:-$SCC_DEFAULT_REPO}"
  local current="${SCC_VERSION_STR:-unknown}"

  # Resolve the target: a pinned SCC_VERSION, else the latest release tag.
  local tag
  if [[ "${SCC_VERSION:-latest}" == latest ]]; then
    scc_info "checking the latest release of $repo ..."
    tag="$(scc_selfupdate_latest_tag "$repo")" \
      || scc_die "could not reach GitHub to find the latest release (network or API rate limit?)"
    [[ -n "$tag" ]] || scc_die "no published release found for $repo"
  else
    tag="$SCC_VERSION"
  fi
  local target="${tag#v}"

  scc_info "installed: scc $current"
  scc_info "latest:    scc $target ($tag)"

  if [[ "$current" == "$target" && "$force" != 1 ]]; then
    scc_info "already up to date."
    return 0
  fi
  if [[ "$check" == 1 ]]; then
    scc_info "run 'scc self-update' to update (add -y to skip the prompt)."
    return 0
  fi
  if [[ "$assume_yes" != 1 && -t 0 && -t 2 ]]; then
    printf 'scc: update from %s to %s? [y/N] ' "$current" "$target" >&2
    local reply=""; read -r reply || true
    case "$reply" in y|Y|yes|YES) ;; *) scc_info "cancelled."; return 0 ;; esac
  fi

  # Fetch the bootstrap installer FROM THE RESOLVED TAG (never a moving branch)
  # to a temp file, sanity-check it, then run it, instead of piping a
  # branch-hosted script straight into a shell. The installer then downloads the
  # matching pinned release tarball (SCC_VERSION=tag).
  local url="https://raw.githubusercontent.com/$repo/$tag/install-remote.sh"
  local tmp; tmp="$(mktemp -d)" || scc_die "cannot create a temp directory"
  # shellcheck disable=SC2064  # expand $tmp now so the trap keeps the right path
  trap "rm -rf '$tmp'" RETURN
  scc_info "downloading the $tag installer ..."
  curl -fsSL "$url" -o "$tmp/install-remote.sh" \
    || scc_die "failed to download the installer from $url"
  [[ -s "$tmp/install-remote.sh" ]] \
    || scc_die "the downloaded installer is empty, refusing to run it"

  scc_info "installing scc $target ..."
  SCC_REPO="$repo" SCC_VERSION="$tag" bash "$tmp/install-remote.sh" \
    || scc_die "install failed (see the output above); your existing scc is unchanged"

  scc_info "scc updated to $target."
  scc_selfupdate_refresh_image
}
