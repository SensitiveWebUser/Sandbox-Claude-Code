#!/usr/bin/env bats
# scc — source-available under PolyForm Noncommercial 1.0.0; see LICENSE.
load helpers

setup() { scc_load_lib; }

@test "guard_workdir refuses \$HOME" {
  cd /tmp; HOME=/tmp
  run scc_guard_workdir
  [ "$status" -ne 0 ]
}

@test "guard_workdir refuses /" {
  cd /; HOME="$BATS_TEST_TMPDIR"
  run scc_guard_workdir
  [ "$status" -ne 0 ]
}

@test "guard_workdir allows a project directory" {
  mkdir -p "$BATS_TEST_TMPDIR/proj"; cd "$BATS_TEST_TMPDIR/proj"; HOME="$BATS_TEST_TMPDIR"
  run scc_guard_workdir
  [ "$status" -eq 0 ]
}

@test "SCC_ALLOW_ANY_DIR=1 bypasses the guard" {
  cd /tmp; HOME=/tmp; SCC_ALLOW_ANY_DIR=1
  run scc_guard_workdir
  [ "$status" -eq 0 ]
}

@test "guard_os refuses a Windows shell" {
  run bash -c "uname() { echo MINGW64_NT-10.0; }; export -f uname; source '$SCC_ROOT/lib/ui.sh'; source '$SCC_ROOT/lib/common.sh'; scc_guard_os"
  [ "$status" -ne 0 ]
}
