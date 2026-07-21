# shellcheck shell=bash
# scc — source-available under PolyForm Noncommercial 1.0.0; see LICENSE.
# lib/commands/help.sh — usage text.

cmd_help() {
  scc_heading "scc — run Claude Code inside an isolated Docker sandbox"
  cat <<'EOF'

From inside a project directory:
  scc [args...]        Claude Code with this directory as its only workspace
                       (args go to claude, e.g. `scc -c`, `scc "fix the tests"`)
  scc yolo [args...]   Same, plus --dangerously-skip-permissions.
                       The egress firewall is ON by default in this mode.
  scc shell            Plain shell inside the sandbox (debugging)

Run flags (before claude args, e.g. `scc --hardened "fix the tests"`):
  --hardened           Max lockdown: read-only rootfs + tmpfs + firewall on.
                       Opt-in; may restrict what the agent can write or reach.

Management:
  scc login            One-time browser login (persists in the home volume)
  scc update           Update Claude Code to the newest release right now
  scc rebuild          Rebuild the image (fresh base OS + baked-in Claude Code)
  scc uninstall        Remove scc (add --all to also drop the volume + image)
  scc help             This text

Configuration (all optional):
  Config file:   ${XDG_CONFIG_HOME:-~/.config}/scc/config   (override: $SCC_CONFIG)
                 key = value; keys: image, volume, pids_limit, firewall,
                 extra_domains, docker_args
  Precedence:    built-in defaults < config file < environment < CLI flags

Environment switches:
  SCC_FIREWALL=1|0               Force egress firewall on/off
                                 (default: off for `scc`, ON for `scc yolo`)
  FIREWALL_EXTRA_DOMAINS=a.com,b.org   Extra domains the firewall allows
  SCC_DOCKER_ARGS="..."          Extra arguments appended to `docker run`
  SCC_ALLOW_ANY_DIR=1            Permit running from $HOME or / (not advised)
  SCC_SKIP_OS_CHECK=1            Skip the operating-system support check

scc is source-available under PolyForm Noncommercial 1.0.0 and is not
affiliated with Anthropic; it runs Anthropic's official Claude Code unmodified.
EOF
}
