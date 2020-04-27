#!/usr/bin/env bash

# ===========================================================================
# Build tests
# ===========================================================================

# ---------------------------------------------------------------------------
testDockerBuildNoCache(){
# ---------------------------------------------------------------------------
# Create directory with create_docker_build_dir then manually
# build the image from scratch (--no-cache)

  create_docker_build_dir >/dev/null
  docker build --no-cache -t local/mok-centos-7 \
    "$DOCKERBUILDTMPDIR/mok-centos-7" >/dev/null
  assertEquals \
    "Check docker build status" \
    "0" "$?"
  cleanup
}

# ---------------------------------------------------------------------------
testDockerBuildExitStatus(){
# ---------------------------------------------------------------------------
# Check that build_container_image works

  build_container_image >/dev/null
  assertEquals \
    "Check docker build status" \
    "0" "$?"
  cleanup
}

# ===========================================================================
# shUnit2 funcs
# ===========================================================================

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
