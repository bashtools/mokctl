#!/usr/bin/env bash

# ---------------------------------------------------------------------------
testMakeCreatesMokctlDeploy(){
# ---------------------------------------------------------------------------

  make 2&>/dev/null
  assertTrue \
    "Check that make creates mokctl.deploy" \
    "[[ -e 'mokctl.deploy' ]]"
}
  
# ---------------------------------------------------------------------------
testBuildDirectoryCreation(){
# ---------------------------------------------------------------------------
  
  # Check that all the files are created in the docker build dir

  local dir
  create_docker_build_dir >/dev/null
  dir="$TMPDIR/mok-centos-7"
  assertTrue \
    "Check that tmpdir is created with the correct files" \
    "[[ -e '$dir/Dockerfile' &&
       -e '$dir/100-crio-bridge.conf' &&
       -e '$dir/entrypoint' &&
       -e '$dir/k8s.conf' &&
       -e '$dir/kubernetes.repo' &&
       -e '$dir/README.md' ]]"
}

# ---------------------------------------------------------------------------
testBuildDirectoryDeletion(){
# ---------------------------------------------------------------------------
  
  # Check that the docker build dir is deleted

  local dir
  create_docker_build_dir
  cleanup
  assertTrue \
    "Check that tmpdir is deleted" "[[ ! -e $TMPDIR ]]"
}

# ---------------------------------------------------------------------------
testRunWithNoArgsShouldFail() {
# ---------------------------------------------------------------------------

  main >/dev/null
  assertTrue \
    "Run with no arguments should fail" \
    "[[ $? -ge 1 ]]"
}

# ---------------------------------------------------------------------------
testRunWithNoArgsShouldFailOutput() {
# ---------------------------------------------------------------------------

  grabMainOutput
  
  assertEquals \
    "Run with no arguments should fail with correct output" \
    "No COMMAND supplied" "${LINES[0]}"   
}

# ---------------------------------------------------------------------------
testRunWithOneArgShouldFail() {
# ---------------------------------------------------------------------------

  main create >/dev/null
  assertTrue \
    "Run with 'mokctl create' should fail" \
    "[[ $? -ge 1 ]]"
}

# ---------------------------------------------------------------------------
testRunWithOneArgShouldFailOutput() {
# ---------------------------------------------------------------------------

  grabMainOutput create
  
  assertEquals \
    "Run with 'mokctl create' should fail with correct output" \
    "No SUBCOMMAND supplied" "${LINES[0]}"   
}

# ---------------------------------------------------------------------------
testNotEnoughOptionsToCreateCluster() {
# ---------------------------------------------------------------------------

  main create cluster >/dev/null
  assertTrue \
    "Run with 'mokctl create cluster' should fail" \
    "[[ $? -ge 1 ]]"
}

# ---------------------------------------------------------------------------
testNotEnoughOptionsToCreateClusterOutput() {
# ---------------------------------------------------------------------------

  grabMainOutput create cluster
  
  assertEquals \
    "Run with 'mokctl create cluster' should fail with correct output" \
    "Please provide the Cluster NAME to create." "${LINES[0]}"   
}

# ---------------------------------------------------------------------------
testNotEnoughOptionsToCreateClusterName() {
# ---------------------------------------------------------------------------

  main create cluster name >/dev/null
  assertTrue \
    "Run with 'create cluster name' should fail" \
    "[[ $? -ge 1 ]]"
}

# ---------------------------------------------------------------------------
testNotEnoughOptionsToCreateClusterNameOutput() {
# ---------------------------------------------------------------------------

  grabMainOutput create cluster mycluster
  
  assertEquals \
    "Run with 'create cluster name' should fail with correct output" \
    "Please provide the number of Masters to create. Must be 1 or more." \
    "${LINES[0]}"
}

# ---------------------------------------------------------------------------
testNotEnoughOptionsToCreateClusterName1() {
# ---------------------------------------------------------------------------

  main create cluster name 1 >/dev/null
  assertTrue \
    "Run with 'create cluster name 1' should fail" \
    "[[ $? -ge 1 ]]"
}

# ---------------------------------------------------------------------------
testNotEnoughOptionsToCreateClusterName1Output() {
# ---------------------------------------------------------------------------

  grabMainOutput create cluster mycluster 1
  
  assertEquals \
    "Run with 'create cluster name 1' should fail with correct output" \
    "Please provide the number of Workers to create." \
    "${LINES[0]}"
}

# ---------------------------------------------------------------------------
testZeroMastersShouldFail() {
# ---------------------------------------------------------------------------

  # Can't create a cluster with 0 masters

  main create cluster name 0 0 >/dev/null
  assertTrue \
    "Run with 'create cluster name 0 0' should fail" \
    "[[ $? -ge 1 ]]"
}

# ---------------------------------------------------------------------------
testZeroMastersShouldFailOutput() {
# ---------------------------------------------------------------------------

  grabMainOutput create cluster mycluster 0 0
  
  assertEquals \
    "Run with 'create cluster name 0 0' should fail with correct output" \
    "Please provide the number of Masters to create. Must be 1 or more." \
    "${LINES[0]}"
}

# ---------------------------------------------------------------------------
testZeroMastersShouldFail2() {
# ---------------------------------------------------------------------------

  # Can't create a cluster with 0 masters and >0 workers

  main create cluster name 0 1
  assertTrue \
    "Run with 'create cluster name 0 0' should fail" \
    "[[ $? -ge 1 ]]"
}

# ---------------------------------------------------------------------------
testZeroMastersShouldFail2Output() {
# ---------------------------------------------------------------------------

  grabMainOutput create cluster mycluster 0 1
  
  assertEquals \
    "Run with 'create cluster name 0 0' should fail with correct output" \
    "Please provide the number of Masters to create. Must be 1 or more." \
    "${LINES[0]}"
}

# ---------------------------------------------------------------------------
testCreateValidClusterCommand() {
# ---------------------------------------------------------------------------

  # Check that all the create cluster vars are set

  parse_options create cluster mycluster 1 0
  assertTrue \
    "Valid command: 'mokctl create cluster name 1 0'" \
    "[[ $CREATE_CLUSTER_NAME == "mycluster" &&
       $CREATE_CLUSTER_NUM_MASTERS == "1" &&
       $CREATE_CLUSTER_NUM_WORKERS == "0" ]]"
}

# ---------------------------------------------------------------------------
setUp() {
# ---------------------------------------------------------------------------
# source mokctl.deploy and disable output of usage().

  . ./mokctl.deploy
  usage() { :; }
}

# ---------------------------------------------------------------------------
grabMainOutput() {
# ---------------------------------------------------------------------------
# Helper function. Sets LINES array to script output.

  local tmpname=`mktemp --tmpdir=/var/tmp`
  main "$@" >$tmpname
  readarray -t LINES <$tmpname
}

# Load and run shUnit2.
. tests/shunit2

# vim:ft=bash:sw=2:et:ts=2:
