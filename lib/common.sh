# shellcheck shell=bash
# scc — source-available under PolyForm Noncommercial 1.0.0; see LICENSE.
#
# lib/common.sh — small shared helpers. Sourcing has no side effects.

# Abort with a message.
scc_die() { scc_err "$*"; exit 1; }

# Trim leading/trailing whitespace.
scc_trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

# Strip one layer of matching surrounding single or double quotes.
scc_strip_quotes() {
  local s="$1"
  if [[ ${#s} -ge 2 && ( "$s" == \"*\" || "$s" == \'*\' ) ]]; then
    s="${s:1:${#s}-2}"
  fi
  printf '%s' "$s"
}

# Membership test: scc_in_list <needle> <item>...
scc_in_list() {
  local needle="$1"; shift
  local item
  for item in "$@"; do [[ "$item" == "$needle" ]] && return 0; done
  return 1
}

# Fail early if docker is missing.
scc_require_docker() {
  scc_has docker \
    || scc_die "docker not found. On Arch: sudo pacman -S docker docker-buildx"
}

# Refuse unsupported operating systems. Linux is supported; macOS is allowed
# but untested (Docker Desktop remaps UIDs differently); native Windows shells
# are refused with a pointer to WSL2. Override with SCC_SKIP_OS_CHECK=1.
scc_guard_os() {
  [[ "${SCC_SKIP_OS_CHECK:-0}" == "1" ]] && return 0
  case "$(uname -s)" in
    Linux) return 0 ;;
    Darwin)
      scc_warn "macOS is not officially supported or tested — Docker Desktop remaps"
      scc_warn "UIDs differently, so file ownership may be wrong. Proceeding anyway."
      scc_warn "Silence this with SCC_SKIP_OS_CHECK=1."
      return 0 ;;
    MINGW*|MSYS*|CYGWIN*|Windows_NT)
      scc_die "Windows is not supported. Install WSL2, then run scc inside a Linux distro." ;;
    *)
      scc_warn "unrecognized OS '$(uname -s)'; proceeding unsupported."
      return 0 ;;
  esac
}

# Refuse to mount $HOME or / into the sandbox.
scc_guard_workdir() {
  [[ "${SCC_ALLOW_ANY_DIR:-0}" == "1" ]] && return 0
  case "$PWD" in
    "$HOME"|/)
      scc_die "refusing to mount $PWD into the sandbox — cd into a project first (override: SCC_ALLOW_ANY_DIR=1)"
      ;;
  esac
}
