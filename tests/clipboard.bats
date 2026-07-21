#!/usr/bin/env bats
# scc: source-available under PolyForm Noncommercial 1.0.0 (see LICENSE).
# Clipboard forwarding (default-on, Wayland) and --screenshots mounts.
load helpers

setup() {
  scc_load_lib
  scc_set_defaults
  ARGS=()
  unset SCC_CLIPBOARD WAYLAND_DISPLAY DISPLAY XDG_RUNTIME_DIR SCC_HARDENED SCC_SCREENSHOTS
}

_mksock() {
  perl -MIO::Socket::UNIX -e 'IO::Socket::UNIX->new(Local=>$ARGV[0],Listen=>1) or die $!' "$1"
}

@test "take_flags parses --no-clipboard and --screenshots" {
  scc_take_flags --no-clipboard --screenshots=/tmp/x -c
  [ "$SCC_CLIPBOARD" = off ]
  [ "$SCC_SCREENSHOTS" = /tmp/x ]
  [ "${SCC_ARGV[0]}" = "-c" ]
}

@test "clipboard forwards the Wayland socket by default (auto)" {
  local sock="$BATS_TEST_TMPDIR/wl.sock"; _mksock "$sock"
  WAYLAND_DISPLAY="$sock" scc_clipboard_args
  local s=" ${ARGS[*]} "
  [[ "$s" == *"$sock:/tmp/scc-wayland.sock"* ]]
  [[ "$s" == *"WAYLAND_DISPLAY=/tmp/scc-wayland.sock"* ]]
}

@test "--no-clipboard disables forwarding" {
  local sock="$BATS_TEST_TMPDIR/wl.sock"; _mksock "$sock"
  SCC_CLIPBOARD=off WAYLAND_DISPLAY="$sock" scc_clipboard_args
  [[ " ${ARGS[*]} " != *scc-wayland* ]]
}

@test "--hardened turns off the auto clipboard" {
  local sock="$BATS_TEST_TMPDIR/wl.sock"; _mksock "$sock"
  SCC_HARDENED=1 WAYLAND_DISPLAY="$sock" scc_clipboard_args
  [[ " ${ARGS[*]} " != *scc-wayland* ]]
}

@test "no Wayland present is a silent no-op (auto)" {
  scc_clipboard_args
  [[ " ${ARGS[*]} " != *scc-wayland* ]]
}

@test "--screenshots mounts an existing dir read-only" {
  local d="$BATS_TEST_TMPDIR/shots"; mkdir -p "$d"
  SCC_SCREENSHOTS="$d" scc_screenshots_args
  [[ " ${ARGS[*]} " == *"$d:$d:ro"* ]]
}

@test "--screenshots skips a missing dir" {
  SCC_SCREENSHOTS="$BATS_TEST_TMPDIR/nope" scc_screenshots_args
  [[ " ${ARGS[*]} " != *nope* ]]
}
