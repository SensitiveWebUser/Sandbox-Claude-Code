# shellcheck shell=bash
# scc — source-available under PolyForm Noncommercial 1.0.0; see LICENSE.
# lib/commands/run.sh — default: Claude Code in the current repo.

cmd_run() {
  scc_run_in_workspace "$(scc_firewall_mode off)" claude "$@"
}
