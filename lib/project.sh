# shellcheck shell=bash
# shellcheck disable=SC2034  # SCC_PROJ_FW_ON is consumed by lib/firewall.sh
# scc: source-available under PolyForm Noncommercial 1.0.0 (see LICENSE).
# lib/project.sh: per-project .scc.conf, trust-gated. A cloned repo is untrusted
# input, so its .scc.conf is ignored until you trust it, and it may set only a
# safe subset of keys (never anything that could loosen the sandbox).

SCC_PROJECT_FILE="${SCC_PROJECT_FILE:-.scc.conf}"
SCC_TRUST_FILE="${SCC_TRUST_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/scc/trust}"
# Keys a project file may set. Deliberately tiny: toolchains (convenience) and
# firewall (enable-only, i.e. a project may only tighten egress).
SCC_PROJ_ALLOWED=(toolchains firewall)

scc_file_sha256() {
  if scc_has sha256sum; then sha256sum "$1" | cut -d' ' -f1
  elif scc_has shasum; then shasum -a 256 "$1" | cut -d' ' -f1
  else return 1; fi
}

# Trust file lines are "<sha256>  <abs-path>". Match on the whole path field
# (everything after the hash), not a substring, so /a/b never matches /a/bc.
scc_project_is_trusted() {  # $1=abs-path $2=sha256
  [ -f "$SCC_TRUST_FILE" ] && grep -qxF "$2  $1" "$SCC_TRUST_FILE"
}

# Drop every entry for a path (any hash), robustly: strip the leading
# "<hash>  " and compare the remainder to the path, so paths with spaces and
# path-prefix collisions are handled correctly.
scc_project_trust_drop() {  # $1=abs-path  (echoes remaining lines)
  [ -f "$SCC_TRUST_FILE" ] || return 0
  awk -v p="$1" '{ line=$0; sub(/^[^ ]+  /, "", line); if (line != p) print }' "$SCC_TRUST_FILE"
}

scc_project_trust_add() {   # $1=abs-path $2=sha256
  mkdir -p "$(dirname "$SCC_TRUST_FILE")"
  if [ -f "$SCC_TRUST_FILE" ]; then          # drop any stale entry for this path
    scc_project_trust_drop "$1" > "$SCC_TRUST_FILE.tmp" && mv "$SCC_TRUST_FILE.tmp" "$SCC_TRUST_FILE"
  fi
  printf '%s  %s\n' "$2" "$1" >> "$SCC_TRUST_FILE"
}

# Handler for a trusted project file. firewall is enable-only (a project may
# only tighten egress, never loosen it); other allowed keys set SCC_PROJ_<key>.
scc_proj_set() {  # $1=key $2=val  (key is already allowlist-checked)
  if [ "$1" = firewall ]; then
    case "$(printf '%s' "$2" | tr '[:upper:]' '[:lower:]')" in
      on|1|true|yes) SCC_PROJ_FW_ON=1 ;;
      *) scc_warn "$SCC_PROJECT_FILE: firewall may only be enabled by a project, not set to '$2', ignoring" ;;
    esac
  else
    printf -v "SCC_PROJ_$1" '%s' "$2"
  fi
}

# Parse a trusted project file into SCC_PROJ_<key> for allowed keys only.
scc_project_parse() {  # $1=file
  scc_kv_parse "$1" "$SCC_PROJECT_FILE" scc_proj_set "${SCC_PROJ_ALLOWED[@]}"
}

# Load $PWD/.scc.conf if present and trusted. Prompts when interactive. Ignores
# (fail-safe) when not. SCC_TRUST_PROJECT=1 honors it for this run only, without
# recording persistent trust (so one-off automation cannot silently whitelist).
scc_project_load() {
  SCC_PROJ_FW_ON=0
  local file="$PWD/$SCC_PROJECT_FILE"
  [ -f "$file" ] || return 0
  local hash
  hash="$(scc_file_sha256 "$file")" \
    || { scc_warn "cannot hash $SCC_PROJECT_FILE (no sha256sum/shasum), ignoring it"; return 0; }

  if scc_project_is_trusted "$file" "$hash"; then
    scc_project_parse "$file"; return 0
  fi
  if [ "${SCC_TRUST_PROJECT:-0}" = 1 ]; then
    scc_info "$SCC_PROJECT_FILE honored for this run only (SCC_TRUST_PROJECT=1), not recorded"
    scc_project_parse "$file"; return 0
  fi
  if [ -t 0 ] && [ -t 2 ]; then
    scc_warn "this repo carries a $SCC_PROJECT_FILE that is not yet trusted:"
    sed 's/^/    /' "$file" >&2
    printf 'scc: trust it (only sets: %s)? [y/N] ' "${SCC_PROJ_ALLOWED[*]}" >&2
    local reply=""; read -r reply || true
    case "$reply" in
      y|Y|yes|YES) scc_project_trust_add "$file" "$hash"; scc_project_parse "$file" ;;
      *)           scc_info "ignoring $SCC_PROJECT_FILE" ;;
    esac
  else
    scc_warn "found an untrusted $SCC_PROJECT_FILE, ignoring it (run 'scc trust' to allow it)"
  fi
}
