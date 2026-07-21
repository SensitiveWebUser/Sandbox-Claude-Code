#!/usr/bin/env bats
# scc: source-available under PolyForm Noncommercial 1.0.0; see LICENSE.
# End-to-end dispatch with `docker` stubbed: assert on the assembled run argv.
load helpers

setup() {
  export PATH="$BATS_TEST_DIRNAME/stubs:$PATH"
  export SCC_DOCKER_LOG="$BATS_TEST_TMPDIR/docker.log"
  export HOME="$BATS_TEST_TMPDIR"
  export SCC_CONFIG="$BATS_TEST_TMPDIR/no-such-config"   # ensure no host config leaks in
  mkdir -p "$BATS_TEST_TMPDIR/proj"
  cd "$BATS_TEST_TMPDIR/proj"
}

@test "default run assembles an open, hardened run" {
  run bash "$SCC_ROOT/scc" -c
  [ "$status" -eq 0 ]
  grep -qx -- '--cap-drop' "$SCC_DOCKER_LOG"
  grep -qx -- 'no-new-privileges:true' "$SCC_DOCKER_LOG"
  ! grep -q 'NET_ADMIN' "$SCC_DOCKER_LOG"
}

@test "yolo enables the firewall" {
  run bash "$SCC_ROOT/scc" yolo
  [ "$status" -eq 0 ]
  grep -q 'NET_ADMIN' "$SCC_DOCKER_LOG"
  grep -qx -- 'SCC_FIREWALL=1' "$SCC_DOCKER_LOG"
}

@test "help works without docker and prints usage" {
  run bash "$SCC_ROOT/scc" help
  [ "$status" -eq 0 ]
  [[ "$output" == *"isolated Docker sandbox"* ]]
}
