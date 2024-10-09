# shellcheck shell=bash disable=SC2148
# GL - Globals

# Private Functions -----------------------------------------------------------

# GL_new sets the only global variables that should be in use anywhere.  The
# only other globals are the associative arrays. All the globals are constant
# (readonly) variables. Declare these globals, where needed, in other files
# so that shellcheck passes.
# Args: None expected.
_GL_new() {

  declare -rg MOKVERSION="0.8.11"
  declare -rg K8SVERSION="1.30.0"
  declare -rg GO_VERSION="1.23.2"

  # Returns, exit codes
  declare -rg OK=0
  declare -rg SUCCESS=0
  declare -rg ERROR=1
  declare -rg FAILURE=1

  # For setting flags
  declare -rg TRUE=1
  declare -rg FALSE=0

  # To signal main() to exit with SUCCESS in the PArser
  declare -rg STOP=2

  declare -rg STDOUT="/dev/stdout"
  declare -rg STDERR="/dev/stderr"

  # The following just keep shellcheck happy
  local dummy dumb
  dummy="${OK}"
  dummy="${ERROR}"
  dummy="${STOP}"
  dummy="${STDOUT}"
  dummy="${STDERR}"
  dummy="${TRUE}"
  dummy="${FALSE}"
  dummy="${SUCCESS}"
  dummy="${FAILURE}"
  dummy="${MOKVERSION}"
  dummy="${GO_VERSION}"
  dummy="${K8SVERSION}"
  dumb="${dummy}${dumb}"
}

# Initialise GL
_GL_new || exit 1

# vim helpers -----------------------------------------------------------------

# The following lines allow the use of '[C-i' and '[I' (do ':help [I') in vim.
#include buildimage.sh
#include containerutils.sh
#include createcluster.sh
#include deletecluster.sh
#include embed-dockerfile.sh
#include error.sh
#include exec.sh
#include getcluster.sh
#include main.sh
#include lib/parser.sh
#include util.sh
#include versions.sh

# vim:ft=sh:sw=2:et:ts=2:
