# shellcheck shell=bash
# scc: source-available under PolyForm Noncommercial 1.0.0; see LICENSE.
# lib/commands/yolo.sh: skip permission prompts; firewall ON by default.
# SCC_HARDENED/SCC_ARGV are set by scc_take_flags.
# shellcheck disable=SC2154

cmd_yolo() {
  scc_take_flags "$@"
  scc_run_in_workspace "$(scc_firewall_mode on)" \
    claude --dangerously-skip-permissions "${SCC_ARGV[@]}"
}
