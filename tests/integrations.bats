#!/usr/bin/env bats
# scc: source-available under PolyForm Noncommercial 1.0.0; see LICENSE.
# --ssh-agent: forward the SSH agent for commit signing and push.
load helpers

setup() { scc_load_lib; scc_set_defaults; ARGS=(); }

@test "take_flags peels --ssh-agent, keeps the rest" {
  scc_take_flags --ssh-agent -c
  [ "$SCC_SSH_AGENT" = 1 ]
  [ "$SCC_HARDENED" = 0 ]
  [ "${SCC_ARGV[0]}" = "-c" ]
}

@test "default workspace_args disables commit signing" {
  scc_base_args open
  scc_workspace_args
  local s=" ${ARGS[*]} "
  [[ "$s" == *"GIT_CONFIG_KEY_0=commit.gpgsign"* ]]
  [[ "$s" == *"GIT_CONFIG_VALUE_0=false"* ]]
}

@test "--ssh-agent forwards the agent socket and leaves signing enabled" {
  local sock="$BATS_TEST_TMPDIR/agent.sock"
  perl -MIO::Socket::UNIX -e 'IO::Socket::UNIX->new(Local=>$ARGV[0],Listen=>1) or die $!' "$sock"
  scc_base_args open
  SCC_SSH_AGENT=1 SSH_AUTH_SOCK="$sock" scc_workspace_args
  local s=" ${ARGS[*]} "
  [[ "$s" == *"$sock:/run/scc-ssh-agent"* ]]
  [[ "$s" == *"SSH_AUTH_SOCK=/run/scc-ssh-agent"* ]]
  [[ "$s" != *"commit.gpgsign"* ]]
}

@test "--ssh-agent fails closed when no agent is available" {
  scc_base_args open
  SCC_SSH_AGENT=1 SSH_AUTH_SOCK="" run scc_workspace_args
  [ "$status" -ne 0 ]
}
