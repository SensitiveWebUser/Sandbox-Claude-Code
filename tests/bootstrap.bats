#!/usr/bin/env bats
# scc — source-available under PolyForm Noncommercial 1.0.0; see LICENSE.
# install-remote.sh: downloads a tarball (here a local file://) and hands off
# to the repo's install.sh. Covers GitHub-style and flat tarball layouts, and
# the unconfigured-repo safety guard.
load helpers

setup() { export HOME="$BATS_TEST_TMPDIR/home"; mkdir -p "$HOME"; }

_pkg() {  # copy the installable files into $1
  cp -R "$SCC_ROOT/Dockerfile" "$SCC_ROOT/entrypoint.sh" "$SCC_ROOT/init-firewall.sh" \
        "$SCC_ROOT/scc" "$SCC_ROOT/install.sh" "$SCC_ROOT/lib" "$1/"
}

@test "installs from a GitHub-style tarball (<repo>-<tag>/...)" {
  local b="$BATS_TEST_TMPDIR/gh"; mkdir -p "$b/scc-9.9.9"; _pkg "$b/scc-9.9.9"
  ( cd "$b" && tar czf scc.tar.gz scc-9.9.9 )
  SCC_TARBALL_URL="file://$b/scc.tar.gz" \
  SCC_DIR="$BATS_TEST_TMPDIR/dot" BIN_DIR="$BATS_TEST_TMPDIR/bin" \
    run bash "$SCC_ROOT/install-remote.sh"
  [ "$status" -eq 0 ]
  [ -x "$BATS_TEST_TMPDIR/bin/scc" ]
  [ -d "$BATS_TEST_TMPDIR/dot/lib" ]
}

@test "installs from a flat tarball (install.sh at top level)" {
  local b="$BATS_TEST_TMPDIR/flat"; mkdir -p "$b/pkg"; _pkg "$b/pkg"
  ( cd "$b/pkg" && tar czf ../flat.tar.gz . )
  SCC_TARBALL_URL="file://$b/flat.tar.gz" \
  SCC_DIR="$BATS_TEST_TMPDIR/dot2" BIN_DIR="$BATS_TEST_TMPDIR/bin2" \
    run bash "$SCC_ROOT/install-remote.sh"
  [ "$status" -eq 0 ]
  [ -x "$BATS_TEST_TMPDIR/bin2/scc" ]
}

@test "refuses an unconfigured placeholder repo (no silent fetch)" {
  SCC_REPO="OWNER/REPO" SCC_VERSION="v1.2.3" run bash "$SCC_ROOT/install-remote.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"no repo configured"* ]]
}
