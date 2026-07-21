#!/usr/bin/env bats
# scc: source-available under PolyForm Noncommercial 1.0.0 (see LICENSE).
# Per-project .scc.conf: trust-gated, restricted allowlist.
load helpers

setup() {
  scc_load_lib
  export SCC_TRUST_FILE="$BATS_TEST_TMPDIR/trust"
  export SCC_PROJECT_FILE=".scc.conf"
  mkdir -p "$BATS_TEST_TMPDIR/repo"
  cd "$BATS_TEST_TMPDIR/repo"
  SCC_PROJ_FW_ON=0
}

@test "parse: allowed keys applied, disallowed keys ignored" {
  printf 'toolchains = python,node\nimage = evil/img\nfirewall = on\n' > .scc.conf
  scc_project_parse .scc.conf
  [ "$SCC_PROJ_toolchains" = "python,node" ]
  [ "$SCC_PROJ_FW_ON" = 1 ]
  [ -z "${SCC_PROJ_image:-}" ]
}

@test "parse: firewall may only be enabled, not disabled" {
  printf 'firewall = off\n' > .scc.conf
  scc_project_parse .scc.conf
  [ "$SCC_PROJ_FW_ON" = 0 ]
}

@test "untrusted config is ignored non-interactively" {
  printf 'toolchains = rust\n' > .scc.conf
  scc_project_load < /dev/null
  [ -z "${SCC_PROJ_toolchains:-}" ]
}

@test "SCC_TRUST_PROJECT=1 applies for this run only, without recording trust" {
  printf 'toolchains = go\n' > .scc.conf
  SCC_TRUST_PROJECT=1 scc_project_load < /dev/null
  [ "$SCC_PROJ_toolchains" = "go" ]
  [ ! -f "$SCC_TRUST_FILE" ]
}

@test "a hash-matching trusted config is applied automatically" {
  printf 'toolchains = python\n' > .scc.conf
  scc_project_trust_add "$PWD/.scc.conf" "$(scc_file_sha256 .scc.conf)"
  scc_project_load < /dev/null
  [ "$SCC_PROJ_toolchains" = "python" ]
}

@test "editing a trusted config re-gates it (hash mismatch -> ignored)" {
  printf 'toolchains = python\n' > .scc.conf
  scc_project_trust_add "$PWD/.scc.conf" "$(scc_file_sha256 .scc.conf)"
  printf 'toolchains = rust\n' > .scc.conf
  scc_project_load < /dev/null
  [ -z "${SCC_PROJ_toolchains:-}" ]
}

@test "resolve: project overrides global config, env overrides project" {
  SCC_PROJ_toolchains=python
  printf 'toolchains = go\n' > "$BATS_TEST_TMPDIR/gconf"
  scc_config_load "$BATS_TEST_TMPDIR/gconf"
  [ "$(scc_resolve toolchains SCC_TC_UNSET "")" = "python" ]
  SCC_TC_ENV=node
  [ "$(scc_resolve toolchains SCC_TC_ENV "")" = "node" ]
}

@test "project firewall=on tightens; explicit env still overrides" {
  SCC_PROJ_FW_ON=1
  [ "$(scc_firewall_mode off)" = "firewall" ]
  SCC_FIREWALL=0
  [ "$(scc_firewall_mode off)" = "open" ]
}
