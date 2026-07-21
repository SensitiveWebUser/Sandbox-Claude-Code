# shellcheck shell=bash
# scc: source-available under PolyForm Noncommercial 1.0.0 (see LICENSE).
# lib/commands/trust.sh: trust/inspect this repo's .scc.conf so scc honors it.
# SCC_PROJECT_FILE / SCC_TRUST_FILE come from lib/project.sh.
# shellcheck disable=SC2154

cmd_trust() {
  local file="$PWD/$SCC_PROJECT_FILE"
  case "${1:-}" in
    --list)
      if [ -f "$SCC_TRUST_FILE" ]; then cat "$SCC_TRUST_FILE"; else scc_info "no trusted project configs"; fi
      ;;
    --remove|--untrust)
      local before=0 after=0
      if [ -f "$SCC_TRUST_FILE" ]; then
        before=$(($(wc -l < "$SCC_TRUST_FILE")))
        scc_project_trust_drop "$file" > "$SCC_TRUST_FILE.tmp" && mv "$SCC_TRUST_FILE.tmp" "$SCC_TRUST_FILE"
        after=$(($(wc -l < "$SCC_TRUST_FILE")))
      fi
      if [ "$before" -ne "$after" ]; then scc_info "removed trust for $file"
      else scc_info "no trust entry for $file"; fi
      ;;
    -h|--help)
      cat <<'EOF'
scc trust: trust this repo's .scc.conf so scc will honor it

  scc trust            Show the file, then trust it (records its checksum)
  scc trust --list     List all trusted project configs
  scc trust --remove   Remove trust for this repo's .scc.conf
EOF
      ;;
    *)
      [ -f "$file" ] || scc_die "no $SCC_PROJECT_FILE in $PWD"
      local hash; hash="$(scc_file_sha256 "$file")" || scc_die "cannot hash $file"
      scc_heading "$SCC_PROJECT_FILE:"
      sed 's/^/  /' "$file"
      scc_project_trust_add "$file" "$hash"
      scc_info "trusted $file"
      ;;
  esac
}
