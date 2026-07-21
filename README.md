# scc: sandboxed Claude Code

Run Claude Code inside an isolated Docker container, from any repo, with one command. Built for plain Docker Engine on Arch Linux: no Docker Desktop, no rootless mode, no userns changes on the host.

`cd` into a project and run `scc`. That directory is bind-mounted into the container at the same absolute path and is the *only* thing on your machine the agent can see. You log in once (persisted in a Docker volume) and Claude Code keeps itself on the newest release via its official native installer's background auto-updater, which writes into that same volume.

> ⚠️ **Independent project, not affiliated with Anthropic.** `scc` is an unofficial, community wrapper. It does **not** own, control, bundle, or represent Claude Code or Anthropic. It installs Anthropic's official CLI at runtime, straight from Anthropic's own installer, and simply runs it inside a container. "Claude" and "Claude Code" are Anthropic's; your use of Claude Code is governed by Anthropic's terms, not this project's. This tool is provided as-is, with no warranty (see [License](#license)).

## How it works, in one paragraph

The image is `node:22-bookworm-slim` plus git and a few tools, with Claude Code installed by Anthropic's official native installer as a non-root user. A small entrypoint runs as root only long enough to remap the container user to your host UID/GID (an edit to the container's own `/etc/passwd`; host namespaces are never touched, and files the agent writes end up owned by you, not root), fix ownership of the persisted home volume, optionally raise a default-deny egress firewall, and then drop privileges with `gosu`. The launcher runs every container with `--cap-drop ALL` plus only the six capabilities the entrypoint needs, `no-new-privileges`, a PID limit (fork-bomb guard), and `--init` for signal handling and zombie reaping. There is no `sudo` in the image.

## Requirements (Arch Linux)

```bash
sudo pacman -Syu docker docker-buildx
sudo systemctl enable --now docker.service
sudo usermod -aG docker "$USER"   # then log out/in, or: newgrp docker
```

Be aware that membership in the `docker` group is root-equivalent on the host. That's a property of Docker itself, independent of anything this sandbox does.

## Install

Quick install (downloads a pinned release, then runs the installer):

```bash
curl -fsSL https://raw.githubusercontent.com/SensitiveWebUser/Sandbox-Claude-Code/main/install-remote.sh | bash
```

Prefer to look before you leap? Download it, read it, then run it:

```bash
curl -fsSL https://raw.githubusercontent.com/SensitiveWebUser/Sandbox-Claude-Code/main/install-remote.sh -o install-remote.sh
less install-remote.sh && bash install-remote.sh
```

Or from a clone:

```bash
cd path/to/these/files
./install.sh      # copies build files + lib/ to ~/.scc and the launcher to ~/.local/bin/scc
scc rebuild       # build the image (a few minutes the first time)
scc login         # one-time browser login, then /exit
```

`scc login` runs the container with host networking so Claude Code's localhost OAuth callback works, and stores the resulting credentials in the `scc-home` volume. Every later run reuses them. If browser login misbehaves, run `claude setup-token` anywhere you have a browser and export the result as `CLAUDE_CODE_OAUTH_TOKEN`. `scc` passes that variable through automatically when it's set.

## Daily use

| Command | What it does |
|---|---|
| `scc` | Claude Code in the current repo, permission prompts on |
| `scc "fix the failing tests"` | Same, with an initial prompt (any `claude` args work, e.g. `scc -c`) |
| `scc yolo` | `--dangerously-skip-permissions`, with the egress firewall **on** by default |
| `scc shell` | A plain shell inside the sandbox, for poking around |
| `scc update` | Jump to the newest Claude Code release immediately |
| `scc rebuild` | Rebuild the image (fresh base OS; also re-pulls the base image) |

The subcommand names (`yolo`, `shell`, `login`, `update`, `rebuild`, `build`, `uninstall`, `help`) are reserved; everything else is passed straight to `claude`.

## The egress firewall

Interactive runs default to full network access; `scc yolo` defaults to a default-deny allowlist, because an agent that skips permission prompts shouldn't also have unrestricted egress. Force it either way with `SCC_FIREWALL=1` or `SCC_FIREWALL=0`.

Allowed out of the box: DNS (only to the resolvers in the container's `resolv.conf`), GitHub's published IP ranges, Anthropic/Claude endpoints, the npm registry, and PyPI. Add more with `FIREWALL_EXTRA_DOMAINS=crates.io,static.crates.io scc yolo`. Two honest limits: domains are resolved to IPs once at container start, so a CDN rotating addresses mid-session can break an allowed host (restart to refresh), and DNS itself remains a narrow exfiltration side channel.

## Hardened mode

The image already drops all Linux capabilities bar the few the entrypoint needs, runs with `no-new-privileges`, and ships with setuid/setgid bits stripped. For a stricter run, add `--hardened`:

```bash
scc --hardened "review this untrusted repo"
```

It makes the container's root filesystem **read-only** (only your repo, the home volume, and small `tmpfs` mounts stay writable) and turns the egress firewall **on**. It's opt-in because it can restrict what an agent may write or reach. Under a read-only rootfs the entrypoint can't edit `/etc/passwd`, so it runs as your numeric host UID directly. No private keys or extra host state involved.

## Configuration file

Everything works with zero configuration. When you want defaults that stick, drop a file at `~/.config/scc/config` (override the path with `$SCC_CONFIG`). It's a simple `key = value` file, parsed with a fixed key allowlist and never executed as code:

```ini
# ~/.config/scc/config
image         = scc:latest
volume        = scc-home
pids_limit    = 4096
firewall      = auto            # auto | on | off
extra_domains = crates.io,static.crates.io
docker_args   = --memory 8g
```

Values resolve as **built-in defaults < config file < environment variables < CLI flags** (later wins), so a one-off `SCC_FIREWALL=1 scc` still overrides the file.

## Staying up to date

Three layers, strongest first: Claude Code's native install auto-updates in the background into the persisted volume, so ordinary use keeps you current; `scc update` runs `claude update` in the container to force the newest release right now; and `scc rebuild` refreshes the base image and the baked-in install (used by fresh volumes). If you ever want reproducibility instead of freshness, pin a version in the Dockerfile (`... install.sh | bash -s -- <version>`) and add `ENV DISABLE_AUTOUPDATER=1`.

## What the sandbox can and cannot touch

Mounted in: the current directory (read-write, same path as on the host), your `~/.gitconfig` (read-only, so commits carry your name; commit signing is disabled inside since no keys are present), and the `scc-home` volume holding Claude's install and credentials. Passed through: `TERM`, `COLORTERM`, and `CLAUDE_CODE_OAUTH_TOKEN` if set.

Not shared: SSH keys, the rest of your home directory, your shell environment, host credentials of any kind. Pushing over SSH therefore won't authenticate from inside. Push from the host, or use HTTPS with a scoped token via `SCC_DOCKER_ARGS="-e GH_TOKEN"`. The launcher also refuses to run from `$HOME` or `/`, since mounting those would defeat the point.

Escape hatch for anything unusual: `SCC_DOCKER_ARGS` appends raw arguments to `docker run` (extra mounts, `--memory 8g`, ports for a dev server, SSH agent forwarding if you accept the exposure).

## Troubleshooting

Login never completes in the browser: make sure you used `scc login` (host networking) rather than logging in from a normal `scc` run; the fallback is `claude setup-token` plus `CLAUDE_CODE_OAUTH_TOKEN` as described above. Containers can't resolve DNS: put `{"dns": ["1.1.1.1", "9.9.9.9"]}` in `/etc/docker/daemon.json` and restart docker, a known quirk on some Arch network setups. `docker: permission denied`: you haven't re-logged-in after joining the `docker` group. Firewalled run can't reach a host it needs: add it to `FIREWALL_EXTRA_DOMAINS`. Weird terminal rendering: your terminfo may be exotic; try `TERM=xterm-256color scc`. Diagnostics from inside: `scc shell`, then `claude doctor`.

## Honest limits

A container is a strong boundary for this purpose, but it is not a VM: the kernel is shared, so treat `scc` as protection against a misbehaving agent, not against a determined kernel exploit. `yolo` mode is *bounded*, not neutralized: within the mounted repo and whatever network you allow it, the agent can still do real things (edit files, commit, hit APIs), so review diffs before pushing. And the one-time login plus first build need normal network access; everything after that is fast.

## Development

The launcher is modular pure Bash (no runtime dependencies): a thin `scc` dispatcher sourcing `lib/` (`ui`, `common`, `config`, `firewall`, `docker`) and one file per subcommand under `lib/commands/`. Running the repo's `./scc` uses that `lib/` directly, so launcher edits take effect without reinstalling; only image changes (`Dockerfile`, `entrypoint.sh`, `init-firewall.sh`) need `./install.sh && scc rebuild`.

Tests are [`bats`](https://github.com/bats-core/bats-core) and stub `docker`, asserting on the assembled `docker run` argv, so the security invariants (capability set, mount set, firewall mode) are checked without a real container:

```bash
shellcheck -x scc lib/*.sh lib/commands/*.sh install.sh entrypoint.sh init-firewall.sh
bats tests
```

CI runs both plus a `docker build` smoke test. Contributions follow the [CLA](./CLA.md); build rules live in [AGENTS.md](./AGENTS.md).

## License

`scc` is **source-available**, not "open source" in the OSI sense. It is licensed under the [PolyForm Noncommercial License 1.0.0](./LICENSE):

- ✅ **Free for any noncommercial use**: personal projects, study, research, hobby, nonprofits, education, government. Use it, modify it, share it.
- 💼 **Commercial use requires a separate license** from the copyright holder, who retains all commercial rights.
- 📝 It comes **as-is, with no warranty** (see the license text).

Contributions are welcome under the [Contributor License Agreement](./CLA.md), which keeps the project's commercial rights with the owner while you retain ownership of your own work.

## Not affiliated with Anthropic

`scc` is independent and unofficial. It is not endorsed by, sponsored by, or partnered with Anthropic, and it does not own or control Claude Code. It installs and runs Anthropic's official CLI without modification. Trademarks belong to their respective owners.
