# scc: source-available under PolyForm Noncommercial 1.0.0; see LICENSE.
# Shared bats helpers.

SCC_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

# Source the library modules for unit testing (no dispatcher, no docker).
scc_load_lib() {
  # shellcheck source=../lib/ui.sh
  source "$SCC_ROOT/lib/ui.sh"
  # shellcheck source=../lib/common.sh
  source "$SCC_ROOT/lib/common.sh"
  # shellcheck source=../lib/config.sh
  source "$SCC_ROOT/lib/config.sh"
  # shellcheck source=../lib/firewall.sh
  source "$SCC_ROOT/lib/firewall.sh"
  # shellcheck source=../lib/docker.sh
  source "$SCC_ROOT/lib/docker.sh"
  # shellcheck source=../lib/toolchains.sh
  source "$SCC_ROOT/lib/toolchains.sh"
  # shellcheck source=../lib/project.sh
  source "$SCC_ROOT/lib/project.sh"
}

# The defaults the dispatcher normally resolves before calling docker helpers.
scc_set_defaults() {
  IMAGE=scc:latest
  VOLUME=scc-home
  PIDS_LIMIT=2048
  EXTRA_DOMAINS=""
  EXTRA_DOCKER_ARGS=""
}
