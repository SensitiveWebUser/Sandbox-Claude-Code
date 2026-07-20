#!/usr/bin/env bats
# scc — source-available under PolyForm Noncommercial 1.0.0; see LICENSE.
load helpers

setup() { scc_load_lib; }

@test "resolve falls back to the built-in default" {
  [ "$(scc_resolve image SCC_IMAGE_UNSET_XYZ scc:latest)" = "scc:latest" ]
}

@test "config file overrides the default" {
  printf 'image = my/img:1\n' > "$BATS_TEST_TMPDIR/config"
  scc_config_load "$BATS_TEST_TMPDIR/config"
  [ "$(scc_resolve image SCC_IMAGE_UNSET_XYZ scc:latest)" = "my/img:1" ]
}

@test "environment overrides the config file" {
  printf 'image = my/img:1\n' > "$BATS_TEST_TMPDIR/config"
  scc_config_load "$BATS_TEST_TMPDIR/config"
  SCC_IMAGE_ENVTEST=env/img:9
  [ "$(scc_resolve image SCC_IMAGE_ENVTEST scc:latest)" = "env/img:9" ]
}

@test "unknown keys are ignored, not set" {
  printf 'evil = rm -rf /\n' > "$BATS_TEST_TMPDIR/config"
  scc_config_load "$BATS_TEST_TMPDIR/config"
  [ -z "${SCC_CFG_evil:-}" ]
}

@test "whitespace is trimmed and surrounding quotes stripped" {
  printf '  volume =  "my-vol"  \n' > "$BATS_TEST_TMPDIR/config"
  scc_config_load "$BATS_TEST_TMPDIR/config"
  [ "$(scc_resolve volume SCC_VOLUME_UNSET scc-home)" = "my-vol" ]
}

@test "comments and blank lines are skipped" {
  printf '# a comment\n\nvolume = ok\n' > "$BATS_TEST_TMPDIR/config"
  scc_config_load "$BATS_TEST_TMPDIR/config"
  [ "$(scc_resolve volume SCC_VOLUME_UNSET scc-home)" = "ok" ]
}
