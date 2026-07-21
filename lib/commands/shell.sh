# shellcheck shell=bash
# scc: source-available under PolyForm Noncommercial 1.0.0; see LICENSE.
# lib/commands/shell.sh: a plain shell inside the sandbox (debugging).
# SCC_HARDENED is set by scc_take_flags.
# shellcheck disable=SC2154

cmd_shell() {
  scc_take_flags "$@"
  scc_project_load
  scc_apply_toolchains
  local def=off; [ "$SCC_HARDENED" = 1 ] && def=on
  scc_run_in_workspace "$(scc_firewall_mode "$def")" bash
}
