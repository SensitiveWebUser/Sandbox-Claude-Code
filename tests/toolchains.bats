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

@test "--with merges with configured toolchains rather than replacing them" {
  _mock_docker
  SCC_CFG_toolchains=python
  scc_take_flags --with rust
  scc_apply_toolchains
  [ "$IMAGE" = "scc:tc-python-rust" ]
}

@test "unknown toolchain is rejected" {
  scc_take_flags --with bogus
  run scc_apply_toolchains
  [ "$status" -ne 0 ]
}

@test "gh toolchain builds a gh layer and passes the host token by name" {
  _mock_docker
  gh() { [ "$1 $2" = "auth token" ] && echo tok-xyz; }
  scc_take_flags --with gh
  scc_apply_toolchains
  [ "$IMAGE" = "scc:tc-gh" ]
  [ "$SCC_GH_TOKEN" = 1 ]
  [ "$GH_TOKEN" = "tok-xyz" ]
  scc_base_args open
  [[ " ${ARGS[*]} " == *" -e GH_TOKEN "* ]]
}

@test "config-driven gh builds the layer but does NOT pass the token (must be explicit)" {
  _mock_docker
  gh() { [ "$1 $2" = "auth token" ] && echo tok-xyz; }
  unset SCC_TOOLCHAINS
  printf 'toolchains = gh\n' > "$BATS_TEST_TMPDIR/gconf"
  scc_config_load "$BATS_TEST_TMPDIR/gconf"
  scc_take_flags        # no --with flag
  scc_apply_toolchains
  [ "$IMAGE" = "scc:tc-gh" ]
  [ "${SCC_GH_TOKEN:-0}" != 1 ]
}
