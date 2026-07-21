# shellcheck shell=bash
# scc: source-available under PolyForm Noncommercial 1.0.0 (see LICENSE).
# lib/commands/profiles.sh: list the home-volume profiles that exist.
# VOLUME is set by the dispatcher (the currently selected profile).
# shellcheck disable=SC2154

cmd_profiles() {
  scc_heading "scc profiles (each is a separate home volume):"
  local found=0 name label
  while IFS= read -r name; do
    found=1
    if [ "$name" = "scc-home" ]; then label="default"; else label="${name#scc-home-}"; fi
    if [ "$name" = "$VOLUME" ]; then
      printf '  * %s  (%s) [active]\n' "$label" "$name"
    else
      printf '    %s  (%s)\n' "$label" "$name"
    fi
  done < <(docker volume ls --format '{{.Name}}' | grep -E '^scc-home(-[A-Za-z0-9_-]+)?$' | sort)
  [ "$found" = 1 ] || scc_info "no profiles yet (created on first use)"
  echo
  scc_dim "Use one with:  scc --profile <name> ...   Reset one with:  docker volume rm <name>"
}
