#!/bin/sh
# scc: source-available under PolyForm Noncommercial 1.0.0; see LICENSE.
# Install requested language toolchains into system paths (never $HOME, so they
# are not shadowed by the runtime home volume). Runs as root at build time.
# Args: toolchain names among go node python rust.
# CARGO_HOME / RUSTUP_HOME are provided by the Dockerfile ENV.
# shellcheck disable=SC2154
set -eu
export DEBIAN_FRONTEND=noninteractive
GO_VERSION=1.22.5

apt_install() {
  apt-get update
  apt-get install -y --no-install-recommends "$@"
}

for tc in "$@"; do
  echo "scc-toolchains: installing $tc"
  case "$tc" in
    python)
      apt_install python3 python3-pip python3-venv
      ;;
    node)
      apt_install ca-certificates curl gnupg
      install -m 0755 -d /etc/apt/keyrings
      # Download first, then dearmor: a piped curl failure is invisible under
      # POSIX sh (no pipefail) and would leave an empty keyring.
      curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key -o /tmp/nodesource.key
      gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg < /tmp/nodesource.key
      rm -f /tmp/nodesource.key
      chmod a+r /etc/apt/keyrings/nodesource.gpg
      echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" \
        > /etc/apt/sources.list.d/nodesource.list
      apt_install nodejs
      ;;
    go)
      arch="$(dpkg --print-architecture)"   # amd64 / arm64 match Go's filenames
      curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-${arch}.tar.gz" -o /tmp/go.tgz
      rm -rf /usr/local/go
      tar -C /usr/local -xzf /tmp/go.tgz
      rm -f /tmp/go.tgz
      ;;
    rust)
      # Download then run: a piped curl|sh failure is invisible under POSIX sh.
      curl -fsSL https://sh.rustup.rs -o /tmp/rustup.sh
      sh /tmp/rustup.sh -y --no-modify-path --profile minimal
      rm -f /tmp/rustup.sh
      # cargo must WRITE into CARGO_HOME at runtime (registry cache, git,
      # .package-cache) as the non-root user, so make these world-writable.
      chmod -R a+rwX "$CARGO_HOME" "$RUSTUP_HOME"
      ;;
    *)
      echo "scc-toolchains: unknown toolchain '$tc'" >&2
      exit 1
      ;;
  esac
done

apt-get clean 2>/dev/null || true
rm -rf /var/lib/apt/lists/*
# Strip any setuid/setgid bits the new packages may have introduced.
find / -xdev -perm /6000 -type f -exec chmod -s {} + 2>/dev/null || true
