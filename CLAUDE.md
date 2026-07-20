# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`scc` ("sandboxed Claude Code") runs Claude Code inside an isolated Docker container. The whole project is four shell/Docker files plus an installer — there is no application code, no build system, no test suite. Changes here are edits to shell scripts and a Dockerfile.

## The four artifacts and how they relate

- **`scc`** — the host-side launcher (bash). Parses the subcommand, assembles a hardened `docker run` argument list, and `exec`s the container. This is where all host-side policy lives (what gets mounted, which capabilities are dropped/added, firewall on/off defaults).
- **`Dockerfile`** — builds `scc:latest` from `node:22-bookworm-slim`. Installs Claude Code via Anthropic's official native installer as the non-root `node` user (uid/gid 1000). Adds `entrypoint.sh` + `init-firewall.sh` to `/usr/local/bin/`.
- **`entrypoint.sh`** (`/bin/sh`, runs as root inside the container) — remaps `node` to the host UID/GID (edits the container's own `/etc/passwd`), fixes ownership of the persisted `/home/node` volume, optionally raises the firewall, then drops to `node` via `gosu` and execs the command.
- **`init-firewall.sh`** (bash, root, invoked only by the entrypoint when `SCC_FIREWALL=1`) — builds a default-deny egress allowlist with iptables/ipset.
- **`install.sh`** — copies `Dockerfile`/`entrypoint.sh`/`init-firewall.sh` to `~/.scc` and `scc` to `~/.local/bin`. At runtime the launcher reads its build files from `$SCC_DIR` (`~/.scc`), **not** from this repo — so editing files here has no effect until you re-run `install.sh`.

Control flow: `scc <cmd>` → `base_args`/`workspace_args` build `$ARGS` → `docker run … entrypoint.sh <cmd>` → entrypoint sets up as root, `gosu`s to `node`, execs `claude` (or `bash`).

## Working on this repo

There is nothing to compile or unit-test. Validate changes by hand:

```bash
# Lint shell scripts (the project relies on shellcheck-clean scripts)
shellcheck scc entrypoint.sh init-firewall.sh install.sh

# Apply local edits so the launcher actually uses them, then rebuild the image
./install.sh
scc rebuild            # docker build --pull -t scc:latest ~/.scc

# Exercise a change
scc shell              # plain shell in the sandbox — poke around, run `claude doctor`
SCC_FIREWALL=1 scc shell   # verify firewall setup path
scc yolo "..."         # firewall ON by default in this mode
```

Note the two-hop edit loop: **edit here → `./install.sh` → `scc rebuild`**. Skipping `install.sh` means the launcher keeps running the old copy in `~/.scc`.

## Invariants to preserve when editing

These are the security properties the project exists to provide — do not weaken them casually:

- **Least privilege in `scc`**: every run uses `--cap-drop ALL` and adds back only the six caps the entrypoint needs (CHOWN, DAC_OVERRIDE, FOWNER, SETUID, SETGID, KILL); the firewall path adds NET_ADMIN + NET_RAW. Also `--security-opt no-new-privileges`, `--pids-limit`, `--init`. There is no `sudo` in the image.
- **Only the current directory is mounted** (`-v "$PWD:$PWD"`, same absolute path), plus `~/.gitconfig` read-only and the `scc-home` volume. SSH keys, the rest of `$HOME`, and host env are deliberately not shared. `guard_workdir` refuses to run from `$HOME` or `/`.
- **Firewall defaults are mode-dependent**: off for interactive `scc`, ON for `scc yolo` (an agent skipping permission prompts shouldn't also have open egress). `SCC_FIREWALL=1|0` overrides.
- **Firewall must fail closed**: `init-firewall.sh` runs `set -euo pipefail`, fetches GitHub ranges *before* tightening policy, and ends with a positive/negative reachability check (GitHub must reach, example.com must not) that `exit 1`s on failure. IPv6 is closed entirely to prevent bypass. Keep the verification step.
- Subcommand names (`yolo`, `shell`, `login`, `update`, `rebuild`, `build`, `help`) are reserved; anything else is passed straight through to `claude`.

## Key env vars (all optional)

`SCC_FIREWALL`, `FIREWALL_EXTRA_DOMAINS` (comma-separated), `SCC_DOCKER_ARGS` (raw args appended to `docker run` — the escape hatch for extra mounts/limits), `SCC_ALLOW_ANY_DIR`, `SCC_IMAGE`, `SCC_DIR`, `SCC_VOLUME`, `SCC_PIDS_LIMIT`, `CLAUDE_CODE_OAUTH_TOKEN` (passed through when set; the fallback to browser login).
