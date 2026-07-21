# shellcheck shell=bash
# scc: source-available under PolyForm Noncommercial 1.0.0; see LICENSE.
# lib/toolchains.sh: opt-in language layers, built on demand atop the base image
# (e.g. `scc --with python,rust`). IMAGE / SCC_BUILD_DIR / SCC_WITH are set by
# the dispatcher and the command.
# shellcheck disable=SC2154

SCC_TOOLCHAINS_KNOWN=(go node python rust)

# Resolve requested toolchains (--with flag, else the config 'toolchains' key),
# build the layered variant image once if it is missing, and point IMAGE at it.
# A no-op when none are requested.
scc_apply_toolchains() {
  local want="${SCC_WITH:-}"
  [ -n "$want" ] || want="$(scc_resolve toolchains SCC_TOOLCHAINS "")"
  [ -n "$want" ] || return 0

  # Validate every request, then emit them in a canonical order so the image
  # tag is stable regardless of how they were listed.
  local reqs=() out=() t k
  read -ra reqs <<< "${want//,/ }"
  for t in ${reqs[@]+"${reqs[@]}"}; do
    if ! scc_in_list "$t" "${SCC_TOOLCHAINS_KNOWN[@]}"; then
      scc_die "unknown toolchain '$t' (known: ${SCC_TOOLCHAINS_KNOWN[*]})"
    fi
  done
  for k in "${SCC_TOOLCHAINS_KNOWN[@]}"; do
    if scc_in_list "$k" ${reqs[@]+"${reqs[@]}"}; then out+=("$k"); fi
  done

  local tc="${out[*]}"
  scc_ensure_image                                   # base image must exist first
  local base="$IMAGE" tag="${IMAGE%:*}:tc-${tc// /-}"
  if ! docker image inspect "$tag" >/dev/null 2>&1; then
    [ -f "$SCC_BUILD_DIR/docker/toolchains/Dockerfile" ] \
      || scc_die "toolchain build files not found under $SCC_BUILD_DIR/docker/toolchains"
    scc_info "building toolchain image $tag (first use; toolchains: $tc)"
    docker build --build-arg "BASE=$base" --build-arg "TOOLCHAINS=$tc" \
      -t "$tag" "$SCC_BUILD_DIR/docker/toolchains"
  fi
  IMAGE="$tag"
}
