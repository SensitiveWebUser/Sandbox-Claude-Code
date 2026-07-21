#!/usr/bin/env bats
# scc: source-available under PolyForm Noncommercial 1.0.0 (see LICENSE).
load helpers

setup() {
  export PATH="$BATS_TEST_DIRNAME/stubs:$PATH"
  export HOME="$BATS_TEST_TMPDIR"
  export SCC_CONFIG="$BATS_TEST_TMPDIR/none"
  mkdir -p "$BATS_TEST_TMPDIR/bin" "$BATS_TEST_TMPDIR/.scc/lib"
  : > "$BATS_TEST_TMPDIR/bin/scc"
}

@test "uninstall -y removes launcher and build dir" {
  BIN_DIR="$BATS_TEST_TMPDIR/bin" SCC_DIR="$BATS_TEST_TMPDIR/.scc" \
    run bash "$SCC_ROOT/scc" uninstall -y
  [ "$status" -eq 0 ]
  [ ! -e "$BATS_TEST_TMPDIR/bin/scc" ]
  [ ! -d "$BATS_TEST_TMPDIR/.scc" ]
}

@test "uninstall aborts (and removes nothing) without confirmation" {
  BIN_DIR="$BATS_TEST_TMPDIR/bin" SCC_DIR="$BATS_TEST_TMPDIR/.scc" \
    run bash -c "printf 'n\n' | BIN_DIR='$BATS_TEST_TMPDIR/bin' SCC_DIR='$BATS_TEST_TMPDIR/.scc' bash '$SCC_ROOT/scc' uninstall"
  [ "$status" -ne 0 ]
  [ -e "$BATS_TEST_TMPDIR/bin/scc" ]
  [ -d "$BATS_TEST_TMPDIR/.scc" ]
}

@test "uninstall --help lists options and removes nothing" {
  BIN_DIR="$BATS_TEST_TMPDIR/bin" SCC_DIR="$BATS_TEST_TMPDIR/.scc" \
    run bash "$SCC_ROOT/scc" uninstall --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"--volume"* ]]
  [ -e "$BATS_TEST_TMPDIR/bin/scc" ]
}

@test "uninstall rejects unknown options" {
  BIN_DIR="$BATS_TEST_TMPDIR/bin" SCC_DIR="$BATS_TEST_TMPDIR/.scc" \
    run bash "$SCC_ROOT/scc" uninstall --bogus
  [ "$status" -ne 0 ]
}
