# shellcheck shell=bash
# scc — source-available under PolyForm Noncommercial 1.0.0; see LICENSE.
#
# lib/config.sh — global config file (key = value).
#
# The file is parsed with a FIXED key allowlist and is NEVER sourced or eval'd,
# so a config file can only set known values — it cannot execute code.
#
# Precedence (later wins):
#   built-in defaults < global config file < environment variables < CLI flags
# (CLI flags are applied by the dispatcher after resolution.)

SCC_CONFIG_FILE="${SCC_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/scc/config}"

# Keys the global config is allowed to set. Each maps to an env var + default
# in the dispatcher via scc_resolve.
SCC_CFG_ALLOWED=(image volume pids_limit firewall extra_domains docker_args)

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
  local key="$1" env_var="$2" def="$3" cfgvar="SCC_CFG_$1"
  if [[ -n "${!env_var+x}" ]]; then printf '%s' "${!env_var}"; return 0; fi
  if [[ -n "${!cfgvar+x}" ]]; then printf '%s' "${!cfgvar}"; return 0; fi
  printf '%s' "$def"
}
