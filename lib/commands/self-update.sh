# shellcheck shell=bash
# scc: source-available under PolyForm Noncommercial 1.0.0 (see LICENSE).
# lib/commands/self-update.sh: update scc itself to the latest GitHub release.
# (`scc update` updates Claude Code inside the sandbox, this updates scc.)

# URL of the bootstrap installer to run. Repo/ref are overridable for testing.
scc_selfupdate_url() {
  local repo="${SCC_REPO:-SensitiveWebUser/Sandbox-Claude-Code}" ref="${SCC_BOOTSTRAP_REF:-main}"
  printf 'https://raw.githubusercontent.com/%s/%s/install-remote.sh' "$repo" "$ref"
}

cmd_self_update() {
  scc_has curl || scc_die "self-update needs curl on the host"
  local url; url="$(scc_selfupdate_url)"
  scc_info "updating scc: reinstalling the latest release via install-remote.sh"
  scc_info "(set SCC_VERSION=vX.Y.Z to pin a specific release)"
  # Hand off to the bootstrap installer, which resolves the latest release tag,
  # downloads that pinned tarball, and reinstalls. exec so we do not read our
  # own launcher file while install.sh is replacing it. SCC_VERSION/SCC_REPO
  # pass through the environment to pin a release or a fork.
  # The single quotes are intentional: $SCC_SELFUPDATE_URL must expand inside
  # the inner bash (passed via env), not in this shell.
  # shellcheck disable=SC2016
  exec env SCC_SELFUPDATE_URL="$url" bash -c 'set -o pipefail; curl -fsSL "$SCC_SELFUPDATE_URL" | bash'
}
