# shellcheck shell=bash
# scc: source-available under PolyForm Noncommercial 1.0.0; see LICENSE.
#
# lib/config.sh: global config (key = value). Parsed with a fixed allowlist and
# never sourced/eval'd, so it can set only known values, never run code.
# Precedence (later wins): defaults < global config < project config < env < flags.

SCC_CONFIG_FILE="${SCC_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/scc/config}"

# Keys the global config is allowed to set. Each maps to an env var + default
# in the dispatcher via scc_resolve.
SCC_CFG_ALLOWED=(image volume pids_limit firewall extra_domains docker_args profile toolchains)

# Load the config file into SCC_CFG_<key> variables. Safe: no eval. Unknown
# keys and malformed lines are warned about and skipped.
scc_config_load() {
  local file="${1:-$SCC_CONFIG_FILE}"
  [[ -f "$file" ]] || return 0
  local line key val
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"                 # strip comments
    line="$(scc_trim "$line")"
    [[ -z "$line" ]] && continue
    if [[ "$line" != *"="* ]]; then
      scc_warn "config: ignoring malformed line: $line"
      continue
    fi
    key="$(scc_trim "${line%%=*}")"
    val="$(scc_strip_quotes "$(scc_trim "${line#*=}")")"
    if scc_in_list "$key" "${SCC_CFG_ALLOWED[@]}"; then
      printf -v "SCC_CFG_${key}" '%s' "$val"
    else
      scc_warn "config: ignoring unknown key '$key'"
    fi
  done < "$file"
}

# Resolve a value with correct precedence: env var wins, then config, then
# default. Usage: scc_resolve <cfg-key> <ENV_VAR> <default>
scc_resolve() {
  local key="$1" env_var="$2" def="$3" cfgvar="SCC_CFG_$1" projvar="SCC_PROJ_$1"
  if [[ -n "${!env_var+x}" ]]; then printf '%s' "${!env_var}"; return 0; fi
  if [[ -n "${!projvar+x}" ]]; then printf '%s' "${!projvar}"; return 0; fi
  if [[ -n "${!cfgvar+x}" ]]; then printf '%s' "${!cfgvar}"; return 0; fi
  printf '%s' "$def"
}
