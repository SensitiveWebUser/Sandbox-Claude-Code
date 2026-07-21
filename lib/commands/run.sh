# shellcheck shell=bash
# scc: source-available under PolyForm Noncommercial 1.0.0; see LICENSE.
# lib/commands/run.sh: default is Claude Code in the current repo.
# SCC_HARDENED/SCC_ARGV are set by scc_take_flags.
# shellcheck disable=SC2154

cmd_run() {
  scc_take_flags "$@"
  scc_project_load
  scc_apply_toolchains
  local def=off; [ "$SCC_HARDENED" = 1 ] && def=on
  scc_run_in_workspace "$(scc_firewall_mode "$def")" claude "${SCC_ARGV[@]}"
}
