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

for f in Dockerfile entrypoint.sh init-firewall.sh scc; do
    [[ -f "$SRC_DIR/$f" ]] \
        || { echo "install.sh: missing '$f' next to install.sh" >&2; exit 1; }
done
[[ -d "$SRC_DIR/lib" ]] \
    || { echo "install.sh: missing 'lib/' next to install.sh" >&2; exit 1; }

mkdir -p "$SCC_DIR" "$BIN_DIR"
install -m 0644 "$SRC_DIR/Dockerfile"       "$SCC_DIR/Dockerfile"
install -m 0755 "$SRC_DIR/entrypoint.sh"    "$SCC_DIR/entrypoint.sh"
install -m 0755 "$SRC_DIR/init-firewall.sh" "$SCC_DIR/init-firewall.sh"
install -m 0755 "$SRC_DIR/scc"              "$BIN_DIR/scc"

# Ship the launcher library (modules + subcommands), replacing any old copy.
rm -rf "${SCC_DIR:?}/lib"
cp -R "$SRC_DIR/lib" "$SCC_DIR/lib"
find "$SCC_DIR/lib" -type f -name '*.sh' -exec chmod 0644 {} +

echo "Installed:"
echo "  $SCC_DIR/{Dockerfile,entrypoint.sh,init-firewall.sh,lib/}"
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
