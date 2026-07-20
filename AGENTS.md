# AGENTS.md — Build Rules for `scc`

**These are hard rules, not suggestions.** They govern every change to this repository, whether made by a human or an agent. `MUST` / `MUST NOT` / `SHOULD` carry their [RFC 2119](https://www.rfc-editor.org/rfc/rfc2119) meaning. If a rule blocks you, **stop and ask** — do not work around it. If two rules conflict, the one earlier in this file wins. This file overrides `CLAUDE.md` and any convenience.

For *why* the project is shaped this way, see [CLAUDE.md](./CLAUDE.md). This file is only *how you must build it*.

---

## 0. The prime directive

Every change MUST leave `scc` **safe by default** and **zero-config on the happy path**. If a change makes the common case require a flag, an env var, or a config file to work, it is wrong — redesign it so the default "just works" and the configuration is optional.

## 1. Simplicity & the "just works" bar

1.1. The happy path (`cd repo && scc`) MUST require **no configuration** and **no arguments**.
1.2. Every new option MUST have a safe default and MUST be optional. Removing an option's value MUST fall back to that default, never to an error.
1.3. You MUST NOT add a required runtime dependency to the **launcher**. `scc`, `install.sh`, and `entrypoint.sh` run on the host/container with only: `bash`/`sh`, `docker`, and coreutils. No node, python, jq, or other interpreter may be *required* to launch. (Tools used *inside* the image are fine; tools used by the *firewall* — `iptables`, `ipset`, `dig`, `jq`, `curl` — are already baked into the image and stay there.)
1.4. Prefer deleting code over adding it. A feature that needs a manual to use is not finished — make it obvious or cut it.

## 2. Modularity & structure

2.1. The launcher stays **pure Bash**. Do **not** rewrite it in another language without an explicit decision recorded in `CLAUDE.md`.
2.2. New launcher logic MUST go into a single-purpose module under `lib/` (see the target layout in `CLAUDE.md`). `scc` at the top level stays a thin dispatcher. One responsibility per file.
2.3. Subcommands MUST be additive. Each new subcommand is its own unit and MUST NOT change the behavior of existing ones. The reserved names are `yolo`, `shell`, `login`, `update`, `rebuild`, `build`, `help` (and, per roadmap, `uninstall`); everything else passes straight to `claude` — preserve that passthrough.
2.4. Extension points (toolchains, profiles, config keys) MUST be data-driven where possible, so adding one is adding data, not editing core control flow.

## 3. Security invariants — NEVER weaken these

These encode the entire reason the project exists. You MUST NOT relax any of them for convenience. Any change that touches them requires an explicit, called-out justification in the PR description and a passing test.

3.1. Every container run MUST keep `--cap-drop ALL`, re-adding **only** the caps actually required: the six the entrypoint needs (CHOWN, DAC_OVERRIDE, FOWNER, SETUID, SETGID, KILL), plus NET_ADMIN + NET_RAW **only** when the firewall is enabled. Adding any other capability requires justification.
3.2. `--security-opt no-new-privileges:true`, `--pids-limit`, and `--init` MUST remain on every run. There MUST be no `sudo` in the image.
3.3. The workspace mount MUST remain **only** the current directory (`-v "$PWD:$PWD"`), plus `~/.gitconfig` read-only and the home volume. You MUST NOT mount `$HOME`, SSH keys, host credentials, or arbitrary host paths by default. `guard_workdir` (refusing `$HOME` and `/`) MUST stay.
3.4. New host state reaching the container MUST be **opt-in and narrow** — a specific passthrough (e.g. a single scoped `gh` token via an explicit flag), never a broad mount or a blanket env dump. Secrets MUST NOT be baked into the image or logged.
3.5. The firewall MUST fail closed: `set -euo pipefail`, fetch allowlist sources *before* tightening policy, keep the final positive/negative reachability check that `exit 1`s on failure, and keep IPv6 closed. If you cannot verify egress is restricted, the run MUST abort, not proceed open.
3.6. `scc yolo` (skip-permissions) MUST keep the firewall **on by default**. An agent that skips prompts does not also get open egress.

## 4. Code quality gates

4.1. Every shell file MUST pass `shellcheck` with no warnings before it is considered done. No suppressions except a commented, justified `# shellcheck disable=...` for a genuine false positive.
4.2. Every shell script MUST start with `set -euo pipefail` (or `set -eu` for `/bin/sh`), and MUST quote all expansions unless word-splitting is intentional and commented.
4.3. Any new non-trivial launcher logic MUST ship with a `bats` test. Security-relevant behavior (mount set, cap set, firewall toggle, workdir guard) MUST be tested. Once CI exists, changes MUST NOT merge with a failing `shellcheck` or `bats` run.
4.4. User-facing failures MUST use the existing `die()` pattern with a clear, actionable message — never a bare non-zero exit or a raw stack of docker errors where a hint would help.

## 5. Licensing & attribution

5.1. The project is **source-available**, licensed under PolyForm Noncommercial 1.0.0 + CLA. You MUST NOT describe it as "open source," "OSI-approved," or "FOSS" anywhere (code, docs, commits, marketing). Use "source-available" or "free for noncommercial use."
5.2. You MUST NOT change the license, add a differently-licensed alternative, or vendor third-party code under an incompatible license without explicit owner approval. Any vendored third-party code MUST have its license recorded.
5.3. New distributable source files that carry a header comment SHOULD include a one-line notice: `# scc — source-available under PolyForm Noncommercial 1.0.0; see LICENSE`. The `Required Notice` line in `LICENSE` MUST carry the real copyright holder before any public release.

## 6. The Anthropic / Claude Code disclaimer

6.1. This project is independent and unofficial. The disclaimer — *not affiliated with Anthropic; does not own, control, or bundle Claude Code; installs Anthropic's official CLI at runtime* — MUST remain present and visible in the README, the Dockerfile, and the `scc` launcher header. You MUST NOT remove or soften it.
6.2. You MUST NOT bundle, fork, patch, or redistribute the Claude Code binary itself. It MUST always be obtained from Anthropic's official installer at build/runtime.
6.3. Do not imply endorsement by, or partnership with, Anthropic anywhere.

## 7. Documentation honesty

7.1. Docs MUST NOT overstate the sandbox. Keep the "container, not a VM; shared kernel; `yolo` is bounded, not neutralized" framing. When you add a boundary, document its limits in the same breath.
7.2. When behavior changes, update `README.md`, `CLAUDE.md`, and any `--help` text in the **same** change. Docs drifting from behavior is a defect.

## 8. Definition of done

A change is done only when **all** hold: happy path still zero-config (§1); no security invariant weakened without justification + test (§3); `shellcheck` clean and tests pass (§4); licensing/attribution intact (§5, §6); docs updated (§7). If any is unmet, it is not done — say so plainly rather than claiming completion.
