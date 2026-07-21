#!/usr/bin/env bats
# scc: source-available under PolyForm Noncommercial 1.0.0; see LICENSE.
# scc_ensure_image: present -> noop, bare tag -> build, registry -> pull.
load helpers

setup() { scc_load_lib; scc_set_defaults; SCC_BUILD_DIR="$SCC_ROOT"; }

@test "already-present image does nothing" {
  docker() { [[ "$1 $2" == "image inspect" ]] && return 0; echo "RAN:$*"; }
  scc_build() { echo "BUILD"; }
  IMAGE="scc:latest"
  run scc_ensure_image
  [ "$status" -eq 0 ]
  [[ "$output" != *"BUILD"* ]]
  [[ "$output" != *"PULL"* ]]
}

@test "bare local tag builds, does not pull" {
  docker() { [[ "$1 $2" == "image inspect" ]] && return 1; echo "RAN:$*"; }
  scc_build() { echo "BUILD"; }
  IMAGE="scc:latest"
  run scc_ensure_image
  [ "$status" -eq 0 ]
  [[ "$output" == *"BUILD"* ]]
}

@test "registry image is pulled, not built" {
  docker() {
    case "$1 $2" in
      "image inspect") return 1 ;;
      "pull "*) echo "PULL:$2"; return 0 ;;
    esac
  }
  scc_build() { echo "BUILD"; }
  IMAGE="ghcr.io/o/scc:1"
  run scc_ensure_image
  [ "$status" -eq 0 ]
  [[ "$output" == *"PULL:ghcr.io/o/scc:1"* ]]
  [[ "$output" != *"BUILD"* ]]
}

@test "registry pull failure falls back to a local build" {
  docker() {
    case "$1 $2" in
      "image inspect") return 1 ;;
      "pull "*) return 1 ;;
    esac
  }
  scc_build() { echo "BUILD"; }
  IMAGE="ghcr.io/o/scc:1"
  run scc_ensure_image
  [ "$status" -eq 0 ]
  [[ "$output" == *"BUILD"* ]]
}
