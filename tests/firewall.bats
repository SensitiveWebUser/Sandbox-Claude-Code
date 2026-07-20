#!/usr/bin/env bats
# scc — source-available under PolyForm Noncommercial 1.0.0; see LICENSE.
load helpers

setup() { scc_load_lib; }

@test "default off yields open" {
  [ "$(scc_firewall_mode off)" = "open" ]
}

@test "default on yields firewall" {
  [ "$(scc_firewall_mode on)" = "firewall" ]
}

@test "SCC_FIREWALL=1 forces firewall even when default is off" {
  SCC_FIREWALL=1
  [ "$(scc_firewall_mode off)" = "firewall" ]
}

@test "SCC_FIREWALL=0 forces open even when default is on" {
  SCC_FIREWALL=0
  [ "$(scc_firewall_mode on)" = "open" ]
}

@test "config firewall=on is honored when env is unset" {
  printf 'firewall = on\n' > "$BATS_TEST_TMPDIR/config"
  scc_config_load "$BATS_TEST_TMPDIR/config"
  [ "$(scc_firewall_mode off)" = "firewall" ]
}
