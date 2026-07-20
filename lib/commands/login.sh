# shellcheck shell=bash
# scc — source-available under PolyForm Noncommercial 1.0.0; see LICENSE.
# lib/commands/login.sh — one-time browser login (persists in the home volume).
#
# Uses host networking so Claude Code's localhost OAuth callback works.
# IMAGE / VOLUME / ARGS are set by the dispatcher + scc_base_args.
# shellcheck disable=SC2154

cmd_login() {
  scc_ensure_image
  scc_info "Opening Claude Code with host networking for the one-time OAuth login."
  scc_info "Finish login in the browser, then /exit. Credentials persist in the"
  scc_info "'$VOLUME' Docker volume; every later 'scc' run reuses them."
  scc_base_args open
  exec docker run "${ARGS[@]}" --network host "$IMAGE" claude
}
