#!/usr/bin/env bats
# scc: source-available under PolyForm Noncommercial 1.0.0 (see LICENSE).
load helpers

setup() { scc_load_lib; scc_set_defaults; }

@test "base_args (open) drops all caps and adds only the six" {
  scc_base_args open
  local s=" ${ARGS[*]} "
  [[ "$s" == *" --cap-drop ALL "* ]]
  [[ "$s" == *" --cap-add CHOWN "* ]]
  [[ "$s" == *" --cap-add DAC_OVERRIDE "* ]]
  [[ "$s" == *" --cap-add FOWNER "* ]]
  [[ "$s" == *" --cap-add SETUID "* ]]
  [[ "$s" == *" --cap-add SETGID "* ]]
  [[ "$s" == *" --cap-add KILL "* ]]
  [[ "$s" != *"NET_ADMIN"* ]]
  [[ "$s" != *"NET_RAW"* ]]
}

@test "base_args always hardens: no-new-privileges, pids-limit, init" {
  scc_base_args open
  local s=" ${ARGS[*]} "
  [[ "$s" == *" --security-opt no-new-privileges:true "* ]]
  [[ "$s" == *" --pids-limit 2048 "* ]]
  [[ "$s" == *" --init "* ]]
  [[ "$s" == *" --rm "* ]]
}

@test "base_args (firewall) adds NET_ADMIN/NET_RAW and enables firewall" {
  scc_base_args firewall
  local s=" ${ARGS[*]} "
  [[ "$s" == *" --cap-add NET_ADMIN "* ]]
  [[ "$s" == *" --cap-add NET_RAW "* ]]
  [[ "$s" == *"SCC_FIREWALL=1"* ]]
}

@test "workspace_args mounts PWD at the same path and sets workdir" {
  scc_base_args open
  scc_workspace_args
  local s=" ${ARGS[*]} "
  [[ "$s" == *" -v $PWD:$PWD "* ]]
  [[ "$s" == *" -w $PWD "* ]]
}

@test "workspace_args disables commit signing" {
  scc_base_args open
  scc_workspace_args
  local s=" ${ARGS[*]} "
  [[ "$s" == *"GIT_CONFIG_KEY_0=commit.gpgsign"* ]]
  [[ "$s" == *"GIT_CONFIG_VALUE_0=false"* ]]
}

@test "extra docker args are appended (word-split)" {
  EXTRA_DOCKER_ARGS="--memory 8g"
  scc_base_args open
  [[ " ${ARGS[*]} " == *" --memory 8g "* ]]
}
