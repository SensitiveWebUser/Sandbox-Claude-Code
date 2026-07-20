# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

> **Read this with [AGENTS.md](./AGENTS.md).** This file is the *what and why* — vision, architecture, roadmap. `AGENTS.md` is the *how* — the strict, non-negotiable rules for building it. When they appear to conflict, `AGENTS.md` wins.

## What this is

`scc` ("sandboxed Claude Code") runs Claude Code inside an isolated Docker container with **only the current directory** mounted. `cd` into a repo, type `scc`, and an agent runs against that repo and nothing else on your machine. The project today is a small set of shell/Docker files — there is no application code, no compiled artifacts, no test suite yet. Work here is edits to shell scripts, a Dockerfile, and docs.

## Project vision

Grow `scc` from a personal helper into a polished, source-available tool that a developer can adopt in **under a minute** and trust with an autonomous agent. Two ideas govern every decision:

1. **"Apple-style, it just works."** The happy path takes zero configuration. Sensible, safe defaults; no flag soup; no required config file. Power is available when you reach for it, invisible when you don't. If a feature needs a manual to use, it isn't done.
2. **Safe by default, honest about limits.** The whole point is running an agent you don't fully trust. Security defaults lean strict (see the invariants below), and the docs never overstate the protection a container provides.

Supporting principles: **modular** (small pieces with clear seams, so features land without touching the core), **buildable-on** (well-defined extension points, so a contributor can add a toolchain or a subcommand without understanding the whole system), and **a well-built core** (the launcher, entrypoint, and firewall are the load-bearing parts and must be tested and rock-solid before breadth is added).

## Licensing (source-available, not OSI-"open")

`scc` is under the **[PolyForm Noncommercial License 1.0.0](./LICENSE)** plus a **[CLA](./CLA.md)**. Anyone may use, modify, and share it for noncommercial purposes; only the copyright holder may commercialize it. This is deliberately **source-available, not "open source"** in the OSI sense — never describe it as "open source" or "OSI-approved" in code, docs, or commit messages. Say **"source-available"** or **"free for noncommercial use."** Every new distributable file that carries a header should carry the noncommercial notice (see `AGENTS.md`).

## Not affiliated with Anthropic

This project is an **independent, unofficial** wrapper. It does **not** own, control, bundle, or represent Claude Code or Anthropic. It installs Anthropic's official CLI at runtime from Anthropic's own installer. "Claude" and "Claude Code" are Anthropic's. This disclaimer must remain visible in the README, the Dockerfile, and the launcher — do not remove it.

## Current architecture — the artifacts and how they relate

- **`scc`** — the host-side launcher (bash). Parses the subcommand, assembles a hardened `docker run` argument list, and `exec`s the container. All host-side policy lives here (what gets mounted, which capabilities are dropped/added, firewall on/off defaults).
- **`Dockerfile`** — builds `scc:latest` from `node:22-bookworm-slim`. Installs Claude Code via Anthropic's official native installer as the non-root `node` user (uid/gid 1000). Adds `entrypoint.sh` + `init-firewall.sh` to `/usr/local/bin/`.
- **`entrypoint.sh`** (`/bin/sh`, runs as root inside the container) — remaps `node` to the host UID/GID (edits the container's own `/etc/passwd`), fixes ownership of the persisted `/home/node` volume, optionally raises the firewall, then drops to `node` via `gosu` and execs the command.
- **`init-firewall.sh`** (bash, root, invoked only by the entrypoint when `SCC_FIREWALL=1`) — builds a default-deny egress allowlist with iptables/ipset.
- **`install.sh`** — copies build files to `~/.scc` and `scc` to `~/.local/bin`.

Control flow: `scc <cmd>` → `base_args`/`workspace_args` build `$ARGS` → `docker run … entrypoint.sh <cmd>` → entrypoint sets up as root, `gosu`s to `node`, execs `claude` (or `bash`).

**The two-hop edit loop (important):** the launcher reads its build files from `$SCC_DIR` (`~/.scc`), **not** from this repo. Edits here are invisible until you re-run `install.sh`. So: **edit here → `./install.sh` → `scc rebuild`.**

## Target architecture (where we're headed)

The launcher stays **pure Bash** — no runtime dependencies, still installable by copying files — but is refactored into small, single-purpose modules so it can grow without becoming a monolith. Chosen over a Go rewrite because zero-install "download and run" *is* the product's simplicity promise; a compiled binary would add a build/release step and make the tool less hackable, and the heavy lifting is already Docker's. Revisit only if Bash becomes the bottleneck for correctness.

Intended shape:

```
scc                 # thin dispatcher: parse subcommand, delegate to lib/
lib/
  common.sh         # die(), logging, shared helpers
  config.sh         # env + per-project config resolution
  docker.sh         # base_args / workspace_args (the run assembly)
  firewall.sh       # host-side firewall toggle logic
  commands/*.sh     # one file per subcommand (run, yolo, shell, login, ...)
tests/*.bats        # bats suite; shellcheck gate over everything
```

## Roadmap (agreed feature direction)

Build in roughly this order; **core hardening and testing before breadth**. Each item must land behind good defaults and stay optional.

1. **Testing + CI + release foundation** — `bats` test suite, `shellcheck` gate, GitHub Actions running both, semver tags + CHANGELOG. This comes first: it's what makes everything after it safe to change.
2. **Public prebuilt image** — publish the base image (preferred: **GitHub Container Registry / GHCR**, alongside the source) so first run doesn't require a local build. Keep local build fully supported.
3. **Image slimming** — the image is ~900 MB today; trim it (leaner base, fewer layers, drop build-only tooling) without losing the tools agents actually need.
4. **First-class git** — a flag/mode that cleanly enables in-sandbox git actions (commit, stash, checkout, branch). Today `~/.gitconfig` is mounted read-only and signing is disabled; extend this thoughtfully. Pushing over SSH is out of scope inside the sandbox by design (no keys mounted).
5. **`gh` CLI access** — let the agent read/track/act on PRs and issues. Design the auth path deliberately: scoped token passed through (never mount host credentials broadly), documented and opt-in, respecting the firewall allowlist.
6. **Language toolchain presets** — opt-in Python/Go/Rust/Node layers (e.g. `scc --with python,rust`) as layered image variants, so the default image stays slim.
7. **Named / persistent profiles** — multiple home volumes (e.g. `--profile work` vs `--profile ctf`) for separate logins/state, plus easy reset.
8. **Per-project config file** — a `.scc.toml`/`.scc.json` a repo can carry (allowed domains, extra mounts, memory, toolchains) so a project "just works" without env-var juggling. Config resolves as: built-in defaults → project file → env vars → CLI flags (later wins).
9. **`uninstall` subcommand + richer `help`** — clean removal (launcher, `~/.scc`, optionally the volume and image) and discoverable help.

## Working on this repo

Nothing to compile or unit-test yet. Validate by hand:

```bash
shellcheck scc entrypoint.sh init-firewall.sh install.sh   # keep shellcheck-clean
./install.sh            # apply local edits so the launcher uses them (two-hop loop)
scc rebuild             # docker build --pull -t scc:latest ~/.scc
scc shell               # plain shell in the sandbox; run `claude doctor`
SCC_FIREWALL=1 scc shell   # exercise the firewall path
```

## Invariants to preserve when editing

These are the security properties the project exists to provide. `AGENTS.md` states them as hard rules; the summary:

- **Least privilege in `scc`**: `--cap-drop ALL` + only the six caps the entrypoint needs (CHOWN, DAC_OVERRIDE, FOWNER, SETUID, SETGID, KILL); firewall path adds NET_ADMIN + NET_RAW. Plus `--security-opt no-new-privileges`, `--pids-limit`, `--init`. No `sudo` in the image.
- **Only the current directory is mounted** (`-v "$PWD:$PWD"`, same absolute path), plus `~/.gitconfig` read-only and the `scc-home` volume. SSH keys, the rest of `$HOME`, and host env are deliberately not shared. `guard_workdir` refuses `$HOME` or `/`.
- **Firewall defaults are mode-dependent**: off for interactive `scc`, ON for `scc yolo`. `SCC_FIREWALL=1|0` overrides.
- **Firewall fails closed**: `init-firewall.sh` runs `set -euo pipefail`, fetches GitHub ranges *before* tightening policy, ends with a positive/negative reachability check that `exit 1`s on failure, and closes IPv6 entirely. Keep the verification step.
- Reserved subcommands (`yolo`, `shell`, `login`, `update`, `rebuild`, `build`, `help`) — anything else passes straight to `claude`.

## Key env vars (all optional)

`SCC_FIREWALL`, `FIREWALL_EXTRA_DOMAINS` (comma-separated), `SCC_DOCKER_ARGS` (raw args appended to `docker run` — escape hatch for extra mounts/limits), `SCC_ALLOW_ANY_DIR`, `SCC_IMAGE`, `SCC_DIR`, `SCC_VOLUME`, `SCC_PIDS_LIMIT`, `CLAUDE_CODE_OAUTH_TOKEN` (passed through when set).
