# shellcheck shell=bash
# scc: source-available under PolyForm Noncommercial 1.0.0; see LICENSE.
#
# lib/firewall.sh: decide whether the egress firewall is on for a run.

# scc_firewall_mode <default>   where default = on|off
# Echoes "firewall" or "open". Resolves the firewall setting from env/config
# (accepts 1/on/true/yes, 0/off/false/no, or auto = use the mode default).
scc_firewall_mode() {
  local def="$1" v
  v="$(scc_resolve firewall SCC_FIREWALL "auto")"
  case "$(printf '%s' "$v" | tr '[:upper:]' '[:lower:]')" in
    1|on|true|yes)  echo firewall ;;
    0|off|false|no) echo open ;;
    auto|"")        [[ "$def" == "on" ]] && echo firewall || echo open ;;
    *)
      scc_warn "unknown firewall setting '$v'; treating as auto"
      [[ "$def" == "on" ]] && echo firewall || echo open ;;
  esac
}
