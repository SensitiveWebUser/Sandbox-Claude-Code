# shellcheck shell=bash
# scc: source-available under PolyForm Noncommercial 1.0.0 (see LICENSE).
#
# lib/firewall.sh: decide whether the egress firewall is on for a run.
# SCC_FIREWALL (env), SCC_CFG_firewall (global config), SCC_HARDENED and
# SCC_PROJ_FW_ON (trusted project, enable-only) come from other modules.
# shellcheck disable=SC2154

# scc_firewall_mode <mode-default>   where mode-default = on|off (off for `scc`,
# on for `scc yolo`). Echoes "firewall" (egress locked down) or "open".
#
# Base precedence (later wins): mode-default < global config < trusted-project
# tighten (on only) < SCC_FIREWALL env. Then --hardened is an ABSOLUTE floor: it
# forces the firewall on even over an explicit off, because it is your own
# max-lockdown request for the run (the override is announced, never silent). A
# trusted project can only tighten over config/default; your explicit env still
# wins, since the trust model protects you from the project, not vice versa.
scc_firewall_mode() {
  local def="$1" v base said_off=0
  if [[ -n "${SCC_FIREWALL:+x}" ]]; then
    v="$SCC_FIREWALL"
  elif [[ "${SCC_PROJ_FW_ON:-0}" == 1 ]]; then
    v=on                                   # trusted project tightens over config
  elif [[ -n "${SCC_CFG_firewall:+x}" ]]; then
    v="$SCC_CFG_firewall"
  else
    v=auto
  fi
  case "$(printf '%s' "$v" | tr '[:upper:]' '[:lower:]')" in
    1|on|true|yes)  base=firewall ;;
    0|off|false|no) base=open; said_off=1 ;;
    auto|"")        [[ "$def" == "on" ]] && base=firewall || base=open ;;
    *)              scc_warn "unknown firewall setting '$v', treating as auto"
                    [[ "$def" == "on" ]] && base=firewall || base=open ;;
  esac
  # --hardened floor: max lockdown always means egress on.
  if [[ "${SCC_HARDENED:-0}" == 1 && "$base" == open ]]; then
    [[ "$said_off" == 1 ]] && scc_warn "--hardened overrides firewall=off: forcing the egress firewall on"
    base=firewall
  fi
  printf '%s\n' "$base"
}
