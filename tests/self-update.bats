#!/usr/bin/env bats
# scc: source-available under PolyForm Noncommercial 1.0.0 (see LICENSE).
# self-update: version-aware update from GitHub releases (decision logic only;
# the actual download/install path needs the network and is not exercised here).
load helpers

setup() {
  scc_load_lib
  source "$SCC_ROOT/lib/commands/self-update.sh"
  SCC_DEFAULT_REPO=owner/repo
  IMAGE=scc:latest
  unset SCC_VERSION SCC_REPO
}

@test "latest_tag parses tag_name out of the release JSON" {
  curl() { printf '{\n  "tag_name": "v9.9.9",\n  "name": "scc"\n}\n'; }
  [ "$(scc_selfupdate_latest_tag owner/repo)" = "v9.9.9" ]
}

@test "already up to date short-circuits with no install" {
  scc_selfupdate_latest_tag() { echo v1.2.3; }
  SCC_VERSION_STR=1.2.3
  run cmd_self_update --check
  [ "$status" -eq 0 ]
  [[ "$output" == *"already up to date"* ]]
}

@test "--check reports installed vs latest and does not install" {
  scc_selfupdate_latest_tag() { echo v2.0.0; }
  SCC_VERSION_STR=1.0.0
  run cmd_self_update --check
  [ "$status" -eq 0 ]
  [[ "$output" == *"installed: scc 1.0.0"* ]]
  [[ "$output" == *"latest:    scc 2.0.0"* ]]
  [[ "$output" != *"installing scc"* ]]
}

@test "unknown option fails with a clear message" {
  run cmd_self_update --bogus
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown option"* ]]
}

@test "--help prints usage and exits 0" {
  run cmd_self_update --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"scc self-update:"* ]]
}
