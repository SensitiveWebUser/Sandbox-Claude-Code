# shellcheck shell=bash
# scc: source-available under PolyForm Noncommercial 1.0.0; see LICENSE.
# lib/commands/update.sh: force Claude Code to the newest release right now.
#
# IMAGE / ARGS are set by the dispatcher + scc_base_args.
# shellcheck disable=SC2154

cmd_update() {
  scc_ensure_image
  scc_base_args open
  exec docker run "${ARGS[@]}" "$IMAGE" claude update
}
