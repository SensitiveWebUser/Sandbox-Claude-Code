#!/usr/bin/env bats
# scc: source-available under PolyForm Noncommercial 1.0.0 (see LICENSE).
# self-update: reinstall the latest release via the bootstrap installer URL.
load helpers

setup() { scc_load_lib; source "$SCC_ROOT/lib/commands/self-update.sh"; }

@test "self-update URL defaults to the project repo on main" {
  unset SCC_REPO SCC_BOOTSTRAP_REF
  [ "$(scc_selfupdate_url)" = "https://raw.githubusercontent.com/SensitiveWebUser/Sandbox-Claude-Code/main/install-remote.sh" ]
}

@test "self-update URL honors SCC_REPO and SCC_BOOTSTRAP_REF" {
  SCC_REPO=me/fork SCC_BOOTSTRAP_REF=dev
  [ "$(scc_selfupdate_url)" = "https://raw.githubusercontent.com/me/fork/dev/install-remote.sh" ]
}
