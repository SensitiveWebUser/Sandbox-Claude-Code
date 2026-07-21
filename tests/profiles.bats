#!/usr/bin/env bats
# scc: source-available under PolyForm Noncommercial 1.0.0 (see LICENSE).
# --profile: select a separate home volume. `profiles` lists them.
load helpers

setup() {
  export PATH="$BATS_TEST_DIRNAME/stubs:$PATH"
  export HOME="$BATS_TEST_TMPDIR"
  export SCC_CONFIG="$BATS_TEST_TMPDIR/none"
  export SCC_DOCKER_LOG="$BATS_TEST_TMPDIR/log"
  mkdir -p "$BATS_TEST_TMPDIR/proj"
  cd "$BATS_TEST_TMPDIR/proj"
}

@test "--profile selects a per-profile home volume" {
  run bash "$SCC_ROOT/scc" --profile work -c
  [ "$status" -eq 0 ]
  grep -qx -- 'scc-home-work:/home/node' "$SCC_DOCKER_LOG"
}

@test "no profile uses the default home volume" {
  run bash "$SCC_ROOT/scc" -c
  [ "$status" -eq 0 ]
  grep -qx -- 'scc-home:/home/node' "$SCC_DOCKER_LOG"
}

@test "--profile=NAME form works and applies to a subcommand" {
  run bash "$SCC_ROOT/scc" --profile=ctf shell
  [ "$status" -eq 0 ]
  grep -qx -- 'scc-home-ctf:/home/node' "$SCC_DOCKER_LOG"
}

@test "invalid profile name is rejected" {
  run bash "$SCC_ROOT/scc" --profile 'bad;name' -c
  [ "$status" -ne 0 ]
}

@test "--profile without a name fails" {
  run bash "$SCC_ROOT/scc" --profile
  [ "$status" -ne 0 ]
}

@test "profiles lists scc home volumes, marks active, ignores others" {
  run bash "$SCC_ROOT/scc" --profile work profiles
  [ "$status" -eq 0 ]
  [[ "$output" == *"work"* ]]
  [[ "$output" == *"[active]"* ]]
  [[ "$output" == *"default"* ]]
  [[ "$output" != *"other-volume"* ]]
}
