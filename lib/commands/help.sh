# shellcheck shell=bash
# scc: source-available under PolyForm Noncommercial 1.0.0; see LICENSE.
# lib/commands/help.sh: usage text.

cmd_help() {
  scc_heading "scc: run Claude Code inside an isolated Docker sandbox"
  cat <<'EOF'

From inside a project directory:
  scc [args...]        Claude Code with this directory as its only workspace
                       (args go to claude, e.g. `scc -c`, `scc "fix the tests"`)
  scc yolo [args...]   Same, plus --dangerously-skip-permissions.
                       The egress firewall is ON by default in this mode.
  scc shell            Plain shell inside the sandbox (debugging)

Global flag (before the subcommand, e.g. `scc --profile work login`):
  --profile NAME       Use a separate home volume (login + state) named NAME.

Run flags (before claude args, e.g. `scc --hardened "fix the tests"`):
  --hardened           Max lockdown: read-only rootfs + tmpfs + firewall on.
                       Opt-in; may restrict what the agent can write or reach.
  --ssh-agent          Forward your SSH agent so in-sandbox git can sign commits
                       and push. Your private key never enters the container.
  --with LIST          Add language toolchains for this run (comma-separated:
                       go, node, python, rust). Built on first use, then cached.

Management:
  scc login            One-time browser login (persists in the home volume)
  scc update           Update Claude Code to the newest release right now
  scc rebuild          Rebuild the image (fresh base OS + baked-in Claude Code)
  scc profiles         List the home-volume profiles that exist
  scc trust            Trust this repo's .scc.conf so scc will honor it
  scc uninstall        Remove scc (add --all to also drop the volume + image)
  scc help             This text

Configuration (all optional):
  Config file:   ${XDG_CONFIG_HOME:-~/.config}/scc/config   (override: $SCC_CONFIG)
                 key = value; keys: image, volume, pids_limit, firewall,
                 extra_domains, docker_args, profile, toolchains
  Project file:  .scc.conf in a repo (trust-gated; may set only toolchains and
                 firewall-on). Ignored until trusted; run `scc trust` to allow.
  Precedence:    defaults < config file < project file < environment < flags

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
