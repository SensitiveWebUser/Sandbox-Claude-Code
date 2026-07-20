# shellcheck shell=bash
# scc — source-available under PolyForm Noncommercial 1.0.0; see LICENSE.
# lib/commands/shell.sh — a plain shell inside the sandbox (debugging).

cmd_shell() {
  scc_run_in_workspace "$(scc_firewall_mode off)" bash
}
