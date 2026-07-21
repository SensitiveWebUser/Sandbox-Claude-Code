# shellcheck shell=bash
# scc: source-available under PolyForm Noncommercial 1.0.0 (see LICENSE).
#
# lib/firewall.sh: decide whether the egress firewall is on for a run.
# SCC_FIREWALL (env), SCC_CFG_firewall (global config), and SCC_PROJ_FW_ON
# (trusted project, enable-only) come from the environment and other modules.
# shellcheck disable=SC2154

# scc_firewall_mode <default>   where default = on|off
# Echoes "firewall" or "open". Precedence: explicit env wins, then a trusted
# project may only TIGHTEN (force on), then global config, then the mode default.
scc_firewall_mode() {
  local def="$1" v
  if [[ -n "${SCC_FIREWALL+x}" ]]; then
    v="$SCC_FIREWALL"
  elif [[ "${SCC_PROJ_FW_ON:-0}" == 1 ]]; then
    echo firewall; return 0
  elif [[ -n "${SCC_CFG_firewall+x}" ]]; then
    v="$SCC_CFG_firewall"
  else
    v="auto"
  fi
  case "$(printf '%s' "$v" | tr '[:upper:]' '[:lower:]')" in
    1|on|true|yes)  echo firewall ;;
    0|off|false|no) echo open ;;
    auto|"")        [[ "$def" == "on" ]] && echo firewall || echo open ;;
    *)
      scc_warn "unknown firewall setting '$v', treating as auto"
      [[ "$def" == "on" ]] && echo firewall || echo open ;;
  esac
}
