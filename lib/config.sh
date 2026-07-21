# shellcheck shell=bash
# scc: source-available under PolyForm Noncommercial 1.0.0 (see LICENSE).
#
# lib/config.sh: global config (key = value). Parsed with a fixed allowlist and
# never sourced/eval'd, so it can set only known values, never run code.
# Precedence (later wins): defaults < global config < project config < env < flags.

SCC_CONFIG_FILE="${SCC_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/scc/config}"

# Keys the global config is allowed to set. Each maps to an env var + default
# in the dispatcher via scc_resolve.
SCC_CFG_ALLOWED=(image volume pids_limit firewall extra_domains docker_args profile toolchains clipboard)

# Parse a key=value file into shell state, safely. For each non-empty,
# non-comment line it validates the key=value shape, trims, strips one layer of
# quotes, and for keys in <allowed...> calls the handler: <handler> <key> <val>.
# Malformed lines and keys outside the allowlist warn (prefixed <label>) and
# are skipped. Never eval'd; the handler decides what an allowed key does.
# Usage: scc_kv_parse <file> <label> <handler-fn> <allowed-key>...
scc_kv_parse() {
  local file="$1" label="$2" handler="$3"; shift 3
  local line key val
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"                 # strip comments
    line="$(scc_trim "$line")"
    [[ -z "$line" ]] && continue
    if [[ "$line" != *"="* ]]; then
      scc_warn "$label: ignoring malformed line: $line"
      continue
    fi
    key="$(scc_trim "${line%%=*}")"
    val="$(scc_strip_quotes "$(scc_trim "${line#*=}")")"
    if scc_in_list "$key" "$@"; then
      "$handler" "$key" "$val"
    else
      scc_warn "$label: ignoring key '$key' (not one of: $*)"
    fi
  done < "$file"
}

# Handler for the global config: set SCC_CFG_<key>. Safe: key is allowlisted.
scc_cfg_set() { printf -v "SCC_CFG_$1" '%s' "$2"; }

# Load the global config file into SCC_CFG_<key> variables.
scc_config_load() {
  local file="${1:-$SCC_CONFIG_FILE}"
  [[ -f "$file" ]] || return 0
  scc_kv_parse "$file" config scc_cfg_set "${SCC_CFG_ALLOWED[@]}"
}

# Resolve a value with correct precedence: env var wins, then project config,
# then global config, then the built-in default. A layer that is unset OR empty
# falls through to the next, so blanking a value (e.g. SCC_IMAGE=) restores the
# default rather than resolving to "" and failing later (AGENTS 1.2).
# Usage: scc_resolve <cfg-key> <ENV_VAR> <default>
scc_resolve() {
  local env_var="$2" def="$3" cfgvar="SCC_CFG_$1" projvar="SCC_PROJ_$1"
  if [[ -n "${!env_var:+x}" ]]; then printf '%s' "${!env_var}"; return 0; fi
  if [[ -n "${!projvar:+x}" ]]; then printf '%s' "${!projvar}"; return 0; fi
  if [[ -n "${!cfgvar:+x}" ]]; then printf '%s' "${!cfgvar}"; return 0; fi
  printf '%s' "$def"
}
