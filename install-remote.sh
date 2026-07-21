#!/usr/bin/env bash
# scc: source-available under PolyForm Noncommercial 1.0.0; see LICENSE.
#
# Remote bootstrap installer:
#
#   curl -fsSL https://raw.githubusercontent.com/SensitiveWebUser/Sandbox-Claude-Code/main/install-remote.sh | bash
#
# It downloads a *pinned release tarball* (never a moving branch) into a temp
# directory and hands off to the repo's own install.sh. Prefer inspecting first:
#
#   curl -fsSL .../install-remote.sh -o install-remote.sh   # then read it
#   bash install-remote.sh
#
# Overrides (env):
#   SCC_REPO=owner/repo     GitHub repo to install from (default below)
#   SCC_VERSION=v1.2.3       Tag to install (default: latest release)
#   SCC_SHA256=<hex>         If set, verify the tarball's sha256. NOTE: GitHub
#                            source archives are NOT byte-stable over time: pin
#                            a checksum only against a fixed SCC_TARBALL_URL
#                            (e.g. an uploaded release asset), not the default.
#   SCC_TARBALL_URL=<url>    Fetch the tarball from here instead (also enables
#                            local testing via a file:// URL)
set -euo pipefail

SCC_REPO="${SCC_REPO:-SensitiveWebUser/Sandbox-Claude-Code}"
SCC_VERSION="${SCC_VERSION:-latest}"

say()  { printf 'scc-install: %s\n' "$*" >&2; }
die()  { printf 'scc-install: %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "required tool '$1' not found"; }

# Refuse unsupported operating systems up front (mirrors lib/common.sh).
if [[ "${SCC_SKIP_OS_CHECK:-0}" != "1" ]]; then
  case "$(uname -s)" in
    Linux) ;;
    Darwin) say "macOS is unofficial/untested; proceeding (set SCC_SKIP_OS_CHECK=1 to silence)." ;;
    MINGW*|MSYS*|CYGWIN*|Windows_NT) die "Windows is not supported. Install WSL2 and run this inside a Linux distro." ;;
    *) say "unrecognized OS '$(uname -s)'; proceeding unsupported." ;;
  esac
fi

need curl
need tar

# Require a configured repo whenever the URL is built from SCC_REPO (both the
# latest and pinned paths); else the placeholder could fetch+run install.sh
# from an unowned github.com/OWNER/REPO. Security-critical.
if [[ -z "${SCC_TARBALL_URL:-}" && "$SCC_REPO" == "OWNER/REPO" ]]; then
  die "no repo configured: set SCC_REPO=owner/repo (or SCC_TARBALL_URL)"
fi

# Resolve "latest" to a concrete tag via the GitHub API (no jq dependency).
if [[ -z "${SCC_TARBALL_URL:-}" && "$SCC_VERSION" == "latest" ]]; then
  say "resolving latest release of $SCC_REPO ..."
  SCC_VERSION="$(
    curl -fsSL "https://api.github.com/repos/$SCC_REPO/releases/latest" \
      | grep -m1 '"tag_name"' | cut -d'"' -f4
  )" || die "could not query the latest release of $SCC_REPO"
  [[ -n "$SCC_VERSION" ]] || die "no releases found for $SCC_REPO"
fi

TARBALL_URL="${SCC_TARBALL_URL:-https://github.com/$SCC_REPO/archive/refs/tags/$SCC_VERSION.tar.gz}"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

say "downloading $TARBALL_URL"
curl -fsSL "$TARBALL_URL" -o "$TMP/scc.tar.gz" || die "download failed"

if [[ -n "${SCC_SHA256:-}" ]]; then
  need sha256sum
  say "verifying checksum"
  printf '%s  %s\n' "$SCC_SHA256" "$TMP/scc.tar.gz" | sha256sum -c - \
    || die "checksum mismatch: refusing to install"
fi

tar -xzf "$TMP/scc.tar.gz" -C "$TMP" || die "could not extract tarball"

# Find install.sh: GitHub layout (depth 2) or flat tarball (depth 1). `sort` for
# determinism; `|| true` so head's SIGPIPE doesn't trip set -e/pipefail.
INSTALLER="$(find "$TMP" -mindepth 1 -maxdepth 2 -name install.sh -type f | sort | head -n1 || true)"
[[ -n "$INSTALLER" ]] || die "install.sh not found inside the tarball"

say "installing (running $(basename "$(dirname "$INSTALLER")")/install.sh)"
bash "$INSTALLER"
