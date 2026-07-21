#!/usr/bin/env bats
# scc: source-available under PolyForm Noncommercial 1.0.0 (see LICENSE).
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

@test "--hardened forces firewall on even when config says off" {
  SCC_CFG_firewall=off SCC_HARDENED=1
  [ "$(scc_firewall_mode off 2>/dev/null)" = "firewall" ]
}

@test "--hardened forces firewall on even when SCC_FIREWALL=0" {
  SCC_FIREWALL=0 SCC_HARDENED=1
  [ "$(scc_firewall_mode off 2>/dev/null)" = "firewall" ]
}

@test "a trusted project's firewall floor beats config off" {
  SCC_CFG_firewall=off SCC_PROJ_FW_ON=1
  [ "$(scc_firewall_mode off 2>/dev/null)" = "firewall" ]
}

@test "floor override of an explicit off is announced" {
  SCC_FIREWALL=0 SCC_HARDENED=1
  run scc_firewall_mode off
  [[ "$output" == *"overrides firewall=off"* ]]
}

@test "default-off plus --hardened does not warn about overriding" {
  SCC_HARDENED=1
  run scc_firewall_mode off
  [ "$status" -eq 0 ]
  [[ "$output" != *"overrides"* ]]
}
