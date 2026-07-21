#!/usr/bin/env bats
# scc — source-available under PolyForm Noncommercial 1.0.0; see LICENSE.
# --hardened flag parsing and its effect on the run args.
load helpers

setup() { scc_load_lib; scc_set_defaults; }

@test "take_flags peels --hardened and keeps the rest" {
  scc_take_flags --hardened -c prompt
  [ "$SCC_HARDENED" = 1 ]
  [ "${SCC_ARGV[0]}" = "-c" ]
  [ "${SCC_ARGV[1]}" = "prompt" ]
}

@test "take_flags without --hardened leaves args intact" {
  scc_take_flags -c
  [ "$SCC_HARDENED" = 0 ]
  [ "${SCC_ARGV[0]}" = "-c" ]
}

@test "-- ends scc-flag parsing (--hardened after it is a claude arg)" {
  scc_take_flags -- --hardened
  [ "$SCC_HARDENED" = 0 ]
  [ "${SCC_ARGV[0]}" = "--hardened" ]
}

@test "hardened base_args adds read-only + hardened tmpfs" {
  SCC_HARDENED=1 scc_base_args open
  local s=" ${ARGS[*]} "
  [[ "$s" == *" --read-only "* ]]
  [[ "$s" == *"/tmp:rw,nosuid,nodev,noexec"* ]]
}

@test "non-hardened base_args has no read-only" {
  SCC_HARDENED=0 scc_base_args open
  [[ " ${ARGS[*]} " != *"--read-only"* ]]
}
