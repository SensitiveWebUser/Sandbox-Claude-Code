# shellcheck shell=bash
# scc — source-available under PolyForm Noncommercial 1.0.0; see LICENSE.
#
# lib/ui.sh — pure-Bash "rich CLI" helpers. Zero dependencies: works with
# nothing installed. Honors NO_COLOR and non-tty output. If `gum`/`fzf` are
# present, callers may light up nicer interactions, but they are never required.

if [[ -t 2 && -z "${NO_COLOR:-}" ]]; then
  SCC_C_RED=$'\033[31m'
  SCC_C_YELLOW=$'\033[33m'
  SCC_C_DIM=$'\033[2m'
  SCC_C_BOLD=$'\033[1m'
  SCC_C_RESET=$'\033[0m'
else
  SCC_C_RED='' SCC_C_YELLOW='' SCC_C_DIM='' SCC_C_BOLD='' SCC_C_RESET=''
fi

# Is a command available on PATH?
scc_has() { command -v "$1" >/dev/null 2>&1; }

# Log levels — all to stderr so stdout stays clean for piping.
scc_err()  { printf '%sscc:%s %s\n' "$SCC_C_RED"    "$SCC_C_RESET" "$*" >&2; }
scc_warn() { printf '%sscc:%s %s\n' "$SCC_C_YELLOW" "$SCC_C_RESET" "$*" >&2; }
scc_info() { printf 'scc: %s\n' "$*" >&2; }

# Rich output primitives (pure Bash).
scc_heading() { printf '%s%s%s\n' "$SCC_C_BOLD" "$*" "$SCC_C_RESET"; }
scc_dim()     { printf '%s%s%s\n' "$SCC_C_DIM"  "$*" "$SCC_C_RESET"; }

# An enhanced interactive picker (fzf/gum) is available.
scc_have_picker() { scc_has fzf || scc_has gum; }
