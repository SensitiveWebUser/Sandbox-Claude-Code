# shellcheck shell=bash
# scc — source-available under PolyForm Noncommercial 1.0.0; see LICENSE.
# lib/commands/yolo.sh — skip permission prompts; firewall ON by default.

cmd_yolo() {
  scc_run_in_workspace "$(scc_firewall_mode on)" \
    claude --dangerously-skip-permissions "$@"
}
