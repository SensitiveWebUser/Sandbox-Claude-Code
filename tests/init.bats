#!/usr/bin/env bats
# scc: source-available under PolyForm Noncommercial 1.0.0 (see LICENSE).
# scc init: scaffold a starter project/global config, trust-gated for projects.
load helpers

setup() {
  export SCC_CONFIG="$BATS_TEST_TMPDIR/gconfig"
  export SCC_TRUST_FILE="$BATS_TEST_TMPDIR/trust"
  scc_load_lib
  source "$SCC_ROOT/lib/commands/init.sh"
  mkdir -p "$BATS_TEST_TMPDIR/proj"
  cd "$BATS_TEST_TMPDIR/proj"
}

@test "init writes a project .scc.conf with only the allowed keys" {
  run cmd_init
  [ "$status" -eq 0 ]
  [ -f .scc.conf ]
  grep -q '^# toolchains = ' .scc.conf
  grep -q '^# firewall = on' .scc.conf
  ! grep -qE '^# (image|docker_args|volume|clipboard) =' .scc.conf
}

@test "init auto-trusts the file it writes" {
  cmd_init
  run scc_project_is_trusted "$PWD/.scc.conf" "$(scc_file_sha256 "$PWD/.scc.conf")"
  [ "$status" -eq 0 ]
}

@test "init refuses to clobber without --force" {
  cmd_init
  run cmd_init
  [ "$status" -ne 0 ]
  [[ "$output" == *"already exists"* ]]
}

@test "init --force overwrites an existing file" {
  cmd_init
  run cmd_init --force
  [ "$status" -eq 0 ]
}

@test "init --global writes the global config with every allowed key" {
  run cmd_init --global
  [ "$status" -eq 0 ]
  [ -f "$SCC_CONFIG" ]
  for k in image volume pids_limit firewall extra_domains docker_args profile toolchains clipboard; do
    grep -q "^# $k = " "$SCC_CONFIG"
  done
}

@test "init rejects unknown options" {
  run cmd_init --bogus
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown option"* ]]
}
