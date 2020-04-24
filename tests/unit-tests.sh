#! /bin/sh
# file: examples/math_test.sh

testCreateValidClusterCommand() {
  parse_options create cluster mycluster 1 0
  assertTrue \
      "Valid command: 'mokctl create cluster name 1 0'" \
  "[[ $CREATE_CLUSTER_NAME == "mycluster" &&
     $CREATE_CLUSTER_NUM_MASTERS == "1" &&
     $CREATE_CLUSTER_NUM_WORKERS == "0" ]]"
}

oneTimeSetUp() {
  # Load include to test.
  . ./mokctl.deploy
}

# Load and run shUnit2.
. tests/shunit2
