# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

> **Read this with [AGENTS.md](./AGENTS.md).** This file is the *what and why*: vision, architecture, roadmap. `AGENTS.md` is the *how*: the strict, non-negotiable rules for building it. When they appear to conflict, `AGENTS.md` wins.

## What this is

`scc` ("sandboxed Claude Code") runs Claude Code inside an isolated Docker container with **only the current directory** mounted. `cd` into a repo, type `scc`, and an agent runs against that repo and nothing else on your machine. The project today is a small set of shell/Docker files: there is no application code, no compiled artifacts, no test suite yet. Work here is edits to shell scripts, a Dockerfile, and docs.

## Project vision

Grow `scc` from a personal helper into a polished, source-available tool that a developer can adopt in **under a minute** and trust with an autonomous agent. Two ideas govern every decision:

1. **"Apple-style, it just works."** The happy path takes zero configuration. Sensible and safe defaults, no flag soup, no required config file. Power is available when you reach for it, invisible when you don't. If a feature needs a manual to use, it isn't done.
2. **Safe by default, honest about limits.** The whole point is running an agent you don't fully trust. Security defaults lean strict (see the invariants below), and the docs never overstate the protection a container provides.

Supporting principles: **modular** (small pieces with clear seams, so features land without touching the core), **buildable-on** (well-defined extension points, so a contributor can add a toolchain or a subcommand without understanding the whole system), and **a well-built core** (the launcher, entrypoint, and firewall are the load-bearing parts and must be tested and rock-solid before breadth is added).

## Licensing (source-available, not OSI-"open")

`scc` is under the **[PolyForm Noncommercial License 1.0.0](./LICENSE)** plus a **[CLA](./CLA.md)**. Anyone may use, modify, and share it for noncommercial purposes. Only the copyright holder may commercialize it. This is deliberately **source-available, not "open source"** in the OSI sense: never describe it as "open source" or "OSI-approved" in code, docs, or commit messages. Say **"source-available"** or **"free for noncommercial use."** Every new distributable file that carries a header should carry the noncommercial notice (see `AGENTS.md`).

## Not affiliated with Anthropic

This project is an **independent, unofficial** wrapper. It does **not** own, control, bundle, or represent Claude Code or Anthropic. It installs Anthropic's official CLI at runtime from Anthropic's own installer. "Claude" and "Claude Code" are Anthropic's. This disclaimer must remain visible in the README, the Dockerfile, and the launcher. Do not remove it.

## Architecture: the artifacts and how they relate

The launcher is **modular pure Bash** (no runtime deps), split so features land without touching the core. Chosen over a Go rewrite because zero-install "download and run" *is* the product's simplicity promise. Revisit only if Bash becomes the bottleneck for correctness.

```
scc                      # thin dispatcher: resolve lib, load config, profile, OS guard, route
lib/
  ui.sh                  # pure-Bash rich CLI: colors, headings, log levels (zero deps)
  common.sh              # scc_die, trim/quote helpers, scc_take_flags, guard_workdir, guard_os
  config.sh              # global config parser (allowlisted key=value) + scc_resolve
  firewall.sh            # scc_firewall_mode: on/off decision (env/config/project/default)
  docker.sh              # base/workspace args, ssh-agent + clipboard + screenshots, build, run
  toolchains.sh          # scc_apply_toolchains: opt-in --with language layers
  project.sh             # trust-gated per-project .scc.conf
  commands/*.sh          # one cmd_<name> per subcommand (run, yolo, shell, login, update,
                         #   self-update, rebuild, profiles, init, trust, uninstall,
                         #   version, help)
Dockerfile               # base image debian:bookworm-slim (Claude Code native binary, no Node)
docker/toolchains/       # opt-in language layers (--with) built on the base
entrypoint.sh            # in-container: remap UID/GID, fix volume ownership, raise firewall, gosu drop
init-firewall.sh         # in-container: default-deny egress allowlist (iptables/ipset)
install.sh               # copies build files + lib/ + docker/ to ~/.scc, launcher to ~/.local/bin
tests/                   # *.bats + helpers.bash + stubs/docker (docker stubbed, asserts on argv)
.github/workflows/       # ci.yml (shellcheck + bats + build/runtime/firewall/toolchain smokes),
                         #   release.yml (vX.Y.Z tag -> GHCR image + GitHub release)
```

Control flow: `scc <cmd>` → source `lib/` + `commands/` → `scc_config_load` + resolve settings → OS/docker guards → `cmd_<name>` → `scc_base_args`/`scc_workspace_args` build `$ARGS` → `docker run … entrypoint.sh` → entrypoint sets up as root, `gosu`s to `node`, execs `claude` (or `bash`).

**Config resolution:** built-in defaults < global config file (`~/.config/scc/config`, `$SCC_CONFIG` to override) < trusted per-project `.scc.conf` < environment variables < CLI flags. Both files are parsed by one shared reader (`scc_kv_parse`) with a fixed key allowlist and are **never** `source`d/`eval`d (see `lib/config.sh`). The default `image` is the published GHCR image (pull, falling back to a local build); `scc rebuild` always builds locally.

**Edit loop:** `scc` sources `lib/` from *next to the script* when present, so **launcher/lib edits in the repo take effect immediately**, no reinstall. Only **image** changes (Dockerfile/entrypoint/firewall) still need `./install.sh` (to copy build files to `~/.scc`) followed by `scc rebuild`.

## Roadmap status

All of the originally agreed milestones are implemented and CI-validated:

- **M0** clean foundation: modular `lib/` refactor, global config, `bats` + `shellcheck` CI, OS guard.
- **M1** distribution: debian base swap (~500 MB), GHCR release workflow, `curl` installer, `uninstall`.
- **Hardening**: setuid strip, `--hardened` (read-only rootfs + tmpfs + firewall on), AGENTS 3.7/3.8.
- **M2** `--ssh-agent`: forward the agent for signing/push, no private keys ever enter the container.
- **M3** named profiles (`--profile`) and language toolchains (`--with gh,go,node,python,rust`).
- **M4** trust-gated per-project `.scc.conf` (may only tighten, never loosen).
- Plus version identity (`VERSION` + `scc version`), a version-aware `scc self-update`, `scc init` to scaffold config, GHCR image consumed by default, clipboard / `--screenshots` image input.

Remaining ideas (not yet built): multi-arch GHCR image, an `scc doctor`. Update this list when scope changes.

## Working on this repo

```bash
shellcheck -x scc lib/*.sh lib/commands/*.sh install.sh install-remote.sh \
  entrypoint.sh init-firewall.sh docker/toolchains/install.sh   # keep clean
bats tests               # unit + stubbed-docker dispatch tests (no real docker needed)
# Launcher/lib edits take effect immediately when running the repo's ./scc.
# Image changes only:
./install.sh && scc rebuild
scc shell                # plain shell in the sandbox, run `claude doctor`
SCC_FIREWALL=1 scc shell # exercise the firewall path
```

## Invariants to preserve when editing

These are the security properties the project exists to provide. `AGENTS.md` states them as hard rules. The summary:

- **Least privilege in `scc`**: `--cap-drop ALL` + only the six caps the entrypoint needs (CHOWN, DAC_OVERRIDE, FOWNER, SETUID, SETGID, KILL). Firewall path adds NET_ADMIN + NET_RAW. Plus `--security-opt no-new-privileges`, `--pids-limit`, `--init`. No `sudo` in the image. The agent never runs as uid 0 (running scc as host root is refused unless `SCC_ALLOW_ROOT=1`).
- **Only the current directory is mounted by default** (`-v "$PWD:$PWD"`, same absolute path), plus `~/.gitconfig` read-only and the `scc-home` volume. SSH keys, the rest of `$HOME`, and host env are deliberately not shared. Opt-in flags may add narrow, announced mounts (`--ssh-agent`, `--with gh` token, `--screenshots`, clipboard forwarding), never by default. `guard_workdir` refuses `$HOME` or `/`.
- **Firewall defaults are mode-dependent**: off for interactive `scc`, ON for `scc yolo`. Base precedence: default < config < trusted-project tighten (on only) < `SCC_FIREWALL`. `--hardened` is then an absolute floor that forces it on even over an explicit `firewall=off`/`SCC_FIREWALL=0` (announced). A trusted `.scc.conf` tightens over config/default only; an explicit `SCC_FIREWALL` still wins.
- **Firewall fails closed**: `init-firewall.sh` runs `set -euo pipefail`, fetches GitHub ranges *before* tightening policy, ends with a positive/negative reachability check that `exit 1`s on failure, and closes IPv6 entirely. Keep the verification step.
- **Integrations grant capability, never secrets** (AGENTS 3.7): check-first, off by default, narrowest passthrough, no private keys in the container, announced when active.
- Reserved subcommands (`yolo`, `shell`, `login`, `update`, `self-update`, `rebuild`, `build`, `profiles`, `init`, `trust`, `uninstall`, `version`, `help`, plus `--version`/`-V`): anything else passes straight to `claude`.

## Key env vars (all optional)

`SCC_FIREWALL`, `FIREWALL_EXTRA_DOMAINS` (comma-separated), `SCC_DOCKER_ARGS` (raw args appended to `docker run`, escape hatch for extra mounts/limits), `SCC_TOOLCHAINS`, `SCC_CLIPBOARD`, `SCC_PROFILE`, `SCC_ALLOW_ANY_DIR`, `SCC_ALLOW_ROOT` (permit running as host root, the agent would run as uid 0), `SCC_SKIP_OS_CHECK`, `SCC_TRUST_PROJECT` (honor a `.scc.conf` for this run only, not recorded), `SCC_IMAGE`, `SCC_DIR`, `SCC_VOLUME`, `SCC_PIDS_LIMIT`, `SCC_CONFIG` (override config-file path), `SCC_REPO`/`SCC_VERSION` (used by the installer and `self-update`), `CLAUDE_CODE_OAUTH_TOKEN` (passed through when set). Each config-backed env var overrides the matching config-file key (`SCC_IMAGE`→`image`, `SCC_VOLUME`→`volume`, `SCC_PIDS_LIMIT`→`pids_limit`, `SCC_FIREWALL`→`firewall`, `FIREWALL_EXTRA_DOMAINS`→`extra_domains`, `SCC_DOCKER_ARGS`→`docker_args`, `SCC_TOOLCHAINS`→`toolchains`, `SCC_CLIPBOARD`→`clipboard`, `SCC_PROFILE`→`profile`).
