#!/usr/bin/env bats
# scc: source-available under PolyForm Noncommercial 1.0.0 (see LICENSE).
# --with: opt-in language toolchain layers (launcher logic only, the actual
# image builds are validated by CI).
load helpers

setup() { scc_load_lib; scc_set_defaults; SCC_BUILD_DIR="$SCC_ROOT"; }

# docker mock: base image present, any :tc-* variant absent (so it "builds").
_mock_docker() {
  docker() {
    if [ "$1" = image ] && [ "$2" = inspect ]; then
      case "$3" in *:tc-*) return 1 ;; *) return 0 ;; esac
    fi
    return 0
  }
}

@test "take_flags peels --with and keeps claude args" {
  scc_take_flags --with python,rust -c
  [ "$SCC_WITH" = "python,rust" ]
  [ "${SCC_ARGV[0]}" = "-c" ]
}

@test "--with builds a canonically-tagged variant and points IMAGE at it" {
  _mock_docker
  scc_take_flags --with rust,python,python
  scc_apply_toolchains
  [ "$IMAGE" = "scc:tc-python-rust" ]
}

@test "no toolchains leaves IMAGE unchanged" {
  SCC_WITH=""
  scc_apply_toolchains
  [ "$IMAGE" = "scc:latest" ]
}

@test "unknown toolchain is rejected" {
  scc_take_flags --with bogus
  run scc_apply_toolchains
  [ "$status" -ne 0 ]
}
