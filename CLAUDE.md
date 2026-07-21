# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

> **Read this with [AGENTS.md](./AGENTS.md).** This file is the *what and why*: vision, architecture, roadmap. `AGENTS.md` is the *how*: the strict, non-negotiable rules for building it. When they appear to conflict, `AGENTS.md` wins.

## What this is

`scc` ("sandboxed Claude Code") runs Claude Code inside an isolated Docker container with **only the current directory** mounted. `cd` into a repo, type `scc`, and an agent runs against that repo and nothing else on your machine. The project today is a small set of shell/Docker files: there is no application code, no compiled artifacts, no test suite yet. Work here is edits to shell scripts, a Dockerfile, and docs.

## Project vision

Grow `scc` from a personal helper into a polished, source-available tool that a developer can adopt in **under a minute** and trust with an autonomous agent. Two ideas govern every decision:

1. **"Apple-style, it just works."** The happy path takes zero configuration. Sensible, safe defaults; no flag soup; no required config file. Power is available when you reach for it, invisible when you don't. If a feature needs a manual to use, it isn't done.
2. **Safe by default, honest about limits.** The whole point is running an agent you don't fully trust. Security defaults lean strict (see the invariants below), and the docs never overstate the protection a container provides.

Supporting principles: **modular** (small pieces with clear seams, so features land without touching the core), **buildable-on** (well-defined extension points, so a contributor can add a toolchain or a subcommand without understanding the whole system), and **a well-built core** (the launcher, entrypoint, and firewall are the load-bearing parts and must be tested and rock-solid before breadth is added).

## Licensing (source-available, not OSI-"open")

`scc` is under the **[PolyForm Noncommercial License 1.0.0](./LICENSE)** plus a **[CLA](./CLA.md)**. Anyone may use, modify, and share it for noncommercial purposes; only the copyright holder may commercialize it. This is deliberately **source-available, not "open source"** in the OSI sense: never describe it as "open source" or "OSI-approved" in code, docs, or commit messages. Say **"source-available"** or **"free for noncommercial use."** Every new distributable file that carries a header should carry the noncommercial notice (see `AGENTS.md`).

## Not affiliated with Anthropic

This project is an **independent, unofficial** wrapper. It does **not** own, control, bundle, or represent Claude Code or Anthropic. It installs Anthropic's official CLI at runtime from Anthropic's own installer. "Claude" and "Claude Code" are Anthropic's. This disclaimer must remain visible in the README, the Dockerfile, and the launcher. Do not remove it.

## Architecture: the artifacts and how they relate

The launcher is **modular pure Bash** (no runtime deps), split so features land without touching the core. Chosen over a Go rewrite because zero-install "download and run" *is* the product's simplicity promise. Revisit only if Bash becomes the bottleneck for correctness.

```
scc                      # thin dispatcher: resolve lib, load config, OS guard, route
lib/
  ui.sh                  # pure-Bash rich CLI: colors, headings, log levels (zero deps)
  common.sh              # scc_die, trim/quote helpers, guard_workdir, guard_os
  config.sh              # global config parser (allowlisted key=value) + scc_resolve
  firewall.sh            # scc_firewall_mode: on/off decision (env/config/default)
  docker.sh              # scc_base_args / scc_workspace_args / build / run
  commands/*.sh          # one cmd_<name> per subcommand (run, yolo, shell, login, update, rebuild, help)
Dockerfile               # builds scc:latest from node:22-bookworm-slim (Anthropic's installer)
entrypoint.sh            # in-container: remap UID/GID, fix volume ownership, raise firewall, gosu→node
init-firewall.sh         # in-container: default-deny egress allowlist (iptables/ipset)
install.sh               # copies build files + lib/ to ~/.scc, launcher to ~/.local/bin
tests/                   # *.bats + helpers.bash + stubs/docker (docker stubbed; asserts on argv)
.github/workflows/ci.yml # shellcheck -x + bats + docker build smoke
```

Control flow: `scc <cmd>` → source `lib/` + `commands/` → `scc_config_load` + resolve settings → OS/docker guards → `cmd_<name>` → `scc_base_args`/`scc_workspace_args` build `$ARGS` → `docker run … entrypoint.sh` → entrypoint sets up as root, `gosu`s to `node`, execs `claude` (or `bash`).

**Config resolution:** built-in defaults < global config file (`~/.config/scc/config`, `$SCC_CONFIG` to override) < environment variables < CLI flags. The config parser uses a fixed key allowlist and is **never** `source`d/`eval`d (see `lib/config.sh`).

**Edit loop:** `scc` sources `lib/` from *next to the script* when present, so **launcher/lib edits in the repo take effect immediately**, no reinstall. Only **image** changes (Dockerfile/entrypoint/firewall) still need `./install.sh` (to copy build files to `~/.scc`) followed by `scc rebuild`.

## Roadmap (agreed feature direction)

Build in roughly this order; **core hardening and testing before breadth**. Each item must land behind good defaults and stay optional. Full milestone detail lives in the plan (`/home/node/.claude/plans/snoopy-launching-haven.md`).

- **✅ M0 (done): clean foundation**. Modular `lib/` refactor, global config file, `bats` tests + `shellcheck` CI, OS guard. Everything below builds on this.
1. **Public prebuilt image**: publish the base image (preferred: **GitHub Container Registry / GHCR**) so first run doesn't require a local build. Keep local build fully supported.
2. **Image slimming**: the image is ~900 MB today; trim it (leaner base, fewer layers) without losing tools agents/firewall need.
3. **First-class git** (opt-in `--git`): enable in-sandbox git incl. **commit signing** by forwarding the signer (SSH-signing via `SSH_AUTH_SOCK`, or gpg-agent). Off by default; today signing is force-disabled because no keys exist in the container.
4. **`gh` CLI, plugged in from the host** (opt-in `--gh`): install `gh`; inject a **token only** via `gh auth token` on the host as `-e GH_TOKEN`. Never mount host `gh`/ssh config.
5. **Language toolchain presets**: opt-in Python/Go/Rust/Node layers (`scc --with python,rust`) as layered image variants; default stays slim.
6. **Named / persistent profiles**: multiple home volumes (`--profile work`) for separate logins/state, plus reset.
7. **Per-project config (`.scc.conf`)**: reuses the config parser with a **restricted, security-gated** allowlist (untrusted cloned-repo input; may only tighten, never loosen; direnv-style repo-trust prompt).
8. **`uninstall` subcommand + richer `help`**: clean removal (launcher, `~/.scc`, optionally the volume/image).

## Working on this repo

```bash
shellcheck -x scc lib/*.sh lib/commands/*.sh install.sh entrypoint.sh init-firewall.sh   # keep clean
bats tests               # unit + stubbed-docker dispatch tests (no real docker needed)
# Launcher/lib edits take effect immediately when running the repo's ./scc.
# Image changes only:
./install.sh && scc rebuild
scc shell                # plain shell in the sandbox; run `claude doctor`
SCC_FIREWALL=1 scc shell # exercise the firewall path
```

## Invariants to preserve when editing

These are the security properties the project exists to provide. `AGENTS.md` states them as hard rules; the summary:

- **Least privilege in `scc`**: `--cap-drop ALL` + only the six caps the entrypoint needs (CHOWN, DAC_OVERRIDE, FOWNER, SETUID, SETGID, KILL); firewall path adds NET_ADMIN + NET_RAW. Plus `--security-opt no-new-privileges`, `--pids-limit`, `--init`. No `sudo` in the image.
- **Only the current directory is mounted** (`-v "$PWD:$PWD"`, same absolute path), plus `~/.gitconfig` read-only and the `scc-home` volume. SSH keys, the rest of `$HOME`, and host env are deliberately not shared. `guard_workdir` refuses `$HOME` or `/`.
- **Firewall defaults are mode-dependent**: off for interactive `scc`, ON for `scc yolo`. `SCC_FIREWALL=1|0` overrides.
- **Firewall fails closed**: `init-firewall.sh` runs `set -euo pipefail`, fetches GitHub ranges *before* tightening policy, ends with a positive/negative reachability check that `exit 1`s on failure, and closes IPv6 entirely. Keep the verification step.
- Reserved subcommands (`yolo`, `shell`, `login`, `update`, `rebuild`, `build`, `help`): anything else passes straight to `claude`.

## Key env vars (all optional)

`SCC_FIREWALL`, `FIREWALL_EXTRA_DOMAINS` (comma-separated), `SCC_DOCKER_ARGS` (raw args appended to `docker run`, escape hatch for extra mounts/limits), `SCC_ALLOW_ANY_DIR`, `SCC_SKIP_OS_CHECK`, `SCC_IMAGE`, `SCC_DIR`, `SCC_VOLUME`, `SCC_PIDS_LIMIT`, `SCC_CONFIG` (override config-file path), `CLAUDE_CODE_OAUTH_TOKEN` (passed through when set). Each config-backed env var (`SCC_IMAGE`→`image`, `SCC_VOLUME`→`volume`, `SCC_PIDS_LIMIT`→`pids_limit`, `SCC_FIREWALL`→`firewall`, `FIREWALL_EXTRA_DOMAINS`→`extra_domains`, `SCC_DOCKER_ARGS`→`docker_args`) overrides the matching config-file key.
