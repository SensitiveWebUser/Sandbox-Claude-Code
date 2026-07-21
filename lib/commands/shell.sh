# shellcheck shell=bash
# scc: source-available under PolyForm Noncommercial 1.0.0 (see LICENSE).
# lib/commands/shell.sh: a shell inside the sandbox (debugging). With extra
# args, runs them as a one-off command in the sandbox instead of an interactive
# shell (e.g. `scc shell claude doctor`). SCC_ARGV is set by scc_take_flags.
# shellcheck disable=SC2154

cmd_shell() {
  scc_take_flags "$@"
  scc_project_load
  scc_apply_toolchains
  if [ "${#SCC_ARGV[@]}" -gt 0 ]; then
    scc_run_in_workspace "$(scc_firewall_mode off)" "${SCC_ARGV[@]}"
  else
    scc_run_in_workspace "$(scc_firewall_mode off)" bash
  fi
}
