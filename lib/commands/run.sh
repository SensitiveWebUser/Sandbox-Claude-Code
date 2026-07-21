# shellcheck shell=bash
# scc: source-available under PolyForm Noncommercial 1.0.0 (see LICENSE).
# lib/commands/run.sh: default is Claude Code in the current repo.
# SCC_HARDENED/SCC_ARGV are set by scc_take_flags.
# shellcheck disable=SC2154

cmd_run() {
  scc_take_flags "$@"
  # A reserved subcommand landing here as the first arg usually means an scc
  # flag preceded it (e.g. `scc --hardened yolo`), so it is being sent to Claude
  # as a prompt instead of dispatched. Warn, but still pass it through.
  if [ "${#SCC_ARGV[@]}" -gt 0 ]; then
    case "${SCC_ARGV[0]}" in
      yolo|shell|login|update|self-update|rebuild|build|profiles|trust|uninstall|init|help|version)
        scc_warn "'${SCC_ARGV[0]}' looks like an scc subcommand but is being passed to Claude as a prompt. Put scc flags after it, e.g. 'scc ${SCC_ARGV[0]} --hardened'." ;;
    esac
  fi
  scc_project_load
  scc_apply_toolchains
  scc_run_in_workspace "$(scc_firewall_mode off)" claude ${SCC_ARGV[@]+"${SCC_ARGV[@]}"}
}
