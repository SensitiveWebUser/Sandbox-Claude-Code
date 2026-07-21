# shellcheck shell=bash
# scc: source-available under PolyForm Noncommercial 1.0.0 (see LICENSE).
# lib/toolchains.sh: opt-in language layers, built on demand atop the base image
# (e.g. `scc --with python,rust`). IMAGE / SCC_BUILD_DIR / SCC_WITH are set by
# the dispatcher and the command.
# shellcheck disable=SC2154,SC2034

SCC_TOOLCHAINS_KNOWN=(gh go node python rust)

# Resolve requested toolchains (--with flag, else the config 'toolchains' key),
# build the layered variant image once if it is missing, and point IMAGE at it.
# A no-op when none are requested.
scc_apply_toolchains() {
  # Merge the per-run --with flag WITH any config/project 'toolchains', so a flag
  # adds to the configured set rather than replacing it. Dedup + canonical order
  # happen below, so overlap and ordering do not matter.
  local flag="${SCC_WITH:-}" cfg
  cfg="$(scc_resolve toolchains SCC_TOOLCHAINS "")"
  local want="$flag,$cfg"
  [ -n "${want//[, ]/}" ] || return 0

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
  # Derive the variant tag from the base repo. Strip the tag only when the last
  # path segment has a colon, so a registry-with-port (localhost:5000/scc) is safe.
  local base="$IMAGE" reporef="$IMAGE"
  if [[ "${IMAGE##*/}" == *:* ]]; then reporef="${IMAGE%:*}"; fi
  local tag="$reporef:tc-${tc// /-}"
  if ! docker image inspect "$tag" >/dev/null 2>&1; then
    [ -f "$SCC_BUILD_DIR/docker/toolchains/Dockerfile" ] \
      || scc_die "toolchain build files not found under $SCC_BUILD_DIR/docker/toolchains"
    scc_info "building toolchain image $tag (first use, toolchains: $tc)"
    docker build --build-arg "BASE=$base" --build-arg "TOOLCHAINS=$tc" \
      -t "$tag" "$SCC_BUILD_DIR/docker/toolchains"
  fi
  IMAGE="$tag"

  # The gh binary is built whenever gh is requested (flag, config, or project),
  # but the TOKEN is a credential grant, so pass it only when gh came from the
  # explicit --with flag, never from config or a trusted .scc.conf.
  local flag_gh=0 _fw=()
  if [ -n "${SCC_WITH:-}" ]; then
    read -ra _fw <<< "${SCC_WITH//,/ }"
    if scc_in_list gh ${_fw[@]+"${_fw[@]}"}; then flag_gh=1; fi
  fi
  if [ "$flag_gh" = 1 ]; then
    local tok=""
    if scc_has gh; then tok="$(gh auth token 2>/dev/null || true)"; fi
    if [ -n "$tok" ]; then
      export GH_TOKEN="$tok"
      SCC_GH_TOKEN=1
      scc_info "gh: passing your host gh token into the sandbox as GH_TOKEN"
    else
      scc_warn "gh: no authenticated host gh found, gh will be unauthenticated in the sandbox"
    fi
  fi
}
