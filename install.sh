#!/usr/bin/env bash
# scc: source-available under PolyForm Noncommercial 1.0.0 (see LICENSE).
# Installer for scc (sandboxed Claude Code).
# Copies the image build files + lib/ to ~/.scc and the launcher to ~/.local/bin/scc.
set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCC_DIR="${SCC_DIR:-$HOME/.scc}"
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"

# Reuse the launcher's OS guard so we refuse unsupported platforms up front.
# shellcheck source=lib/ui.sh
. "$SRC_DIR/lib/ui.sh"
# shellcheck source=lib/common.sh
. "$SRC_DIR/lib/common.sh"
scc_guard_os

for f in Dockerfile entrypoint.sh init-firewall.sh scc VERSION; do
    [[ -f "$SRC_DIR/$f" ]] \
        || { echo "install.sh: missing '$f' next to install.sh" >&2; exit 1; }
done
for d in lib docker/toolchains; do
    [[ -d "$SRC_DIR/$d" ]] \
        || { echo "install.sh: missing '$d/' next to install.sh" >&2; exit 1; }
done

mkdir -p "$SCC_DIR" "$BIN_DIR"
install -m 0644 "$SRC_DIR/Dockerfile"       "$SCC_DIR/Dockerfile"
install -m 0755 "$SRC_DIR/entrypoint.sh"    "$SCC_DIR/entrypoint.sh"
install -m 0755 "$SRC_DIR/init-firewall.sh" "$SCC_DIR/init-firewall.sh"
install -m 0644 "$SRC_DIR/VERSION"          "$SCC_DIR/VERSION"
install -m 0755 "$SRC_DIR/scc"              "$BIN_DIR/scc"

# Ship the launcher library and the toolchain build context. Copy into a
# sibling first, then swap with a rename, so an interrupted or failed copy
# leaves the previous directory intact instead of a half-populated one.
swap_dir() {  # $1=name under $SCC_DIR
    local dst="$SCC_DIR/$1" staged="$SCC_DIR/$1.new"
    rm -rf "${staged:?}"
    cp -R "$SRC_DIR/$1" "$staged"
    if [[ "$1" == lib ]]; then find "$staged" -type f -name '*.sh' -exec chmod 0644 {} +; fi
    rm -rf "${dst:?}"
    mv "$staged" "$dst"
}
swap_dir lib
swap_dir docker

echo "Installed:"
echo "  $SCC_DIR/{Dockerfile,entrypoint.sh,init-firewall.sh,VERSION,lib/,docker/}"
echo "  $BIN_DIR/scc"

case ":$PATH:" in
    *":$BIN_DIR:"*) ;;
    *)
        echo
        echo "NOTE: $BIN_DIR is not in your PATH. Add this to your shell rc:"
        echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
        ;;
esac

cat <<'EOF'

Next steps:
  scc rebuild                    # build the image (first time takes a few minutes)
  scc login                      # one-time browser login, then /exit
  cd ~/some/repo && scc          # daily use
EOF
