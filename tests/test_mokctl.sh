#!/usr/bin/env bats

@test "Testing 'make'" {
  run make
  [ $status -eq 0 ]
}

@test "Was mokctl.deploy created and is it executable" {
  [ -x mokctl.deploy ]
}

# ---- parser checks ----

@test "No args should fail" {
  run ./mokctl.deploy
  [[ ${lines[0]} == "Usage: mokctl"* ]]
}

@test "One arg should fail" {
  run ./mokctl.deploy arg1
  [[ ${lines[0]} == "Usage: mokctl"* ]]
}

@test "Not enough options: 'mokctl create cluster'" {
  run ./mokctl.deploy create cluster
  [[ ${lines[0]} == "Usage: mokctl"* ]]
}

@test "Not enough options: 'mokctl create cluster name'" {
  run ./mokctl.deploy create cluster name
  [[ ${lines[0]} == "Usage: mokctl"* ]]
}

@test "Not enough options: 'mokctl create cluster name 1'" {
  run ./mokctl.deploy create cluster name 1
  [[ ${lines[0]} == "Usage: mokctl"* ]]
}

@test "Zero masters fail: 'mokctl create cluster name 0 0'" {
  run ./mokctl.deploy create cluster name 0 0
  [[ ${lines[0]} == "Usage: mokctl"* ]]
}

# vim:ft=bash:sw=2:et:ts=2:
