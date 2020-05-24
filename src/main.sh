# MAIN - execution starts here

# Defined in GL (globals.sh)
declare OK ERROR STOP STDERR

# main is the start point for this application.
# Args: arg1-N - the command line arguments sent by the user.
main() {

  trap cleanup EXIT
  init || return
  sanity_checks || return

  local retval="${OK}"
  PA_parse_options "$@" || retval=$?
  if [[ ${retval} -eq ${ERROR} ]]; then
    return "${ERROR}"
  elif [[ ${retval} -eq ${STOP} ]]; then
    return "${OK}"
  fi

  local cmd
  cmd=$(PA_command) || err || return
  case "${cmd}" in
  create) do_create ;;
  delete) do_delete ;;
  build) do_build ;;
  get) do_get ;;
  exec) do_exec ;;
  *)
    printf 'INTERNAL ERROR: This should not happen.' >"${STDERR}"
    err || return "${ERROR}"
    ;;
  esac
}

# init sets start values for variables and calls the init in each utility
# 'module'. Other XX_new functions are called in the parser when it knows
# what command and subcommand the user has requested.
# Args: No args expected.
init() {
  GL_new || return # <- new globals
  ER_new || return # <- new error
  UT_new || return # <- new utilities
  PA_new || return # <- new parser
  CU_new || return # <- new container utils
}

# cleanup is called from an EXIT trap only, when the program exits.
# It calls the cleanup functions from other 'modules'.
# Args: No args expected.
cleanup() {
  local retval="${OK}"
  UT_cleanup || retval=$?
  CU_cleanup || retval=$?
  BI_cleanup || retval=$?
  return "${retval}"
}

# do_create chooses which function to run for 'create SUBCOMMAND'.
# Args: No args expected.
do_create() {

  case $(PA_get_subcommand) in
  cluster)
    CC_sanity_checks || return
    CC_cluster_create
    ;;
  *)
    printf 'INTERNAL ERROR: This should not happen.' >"${STDERR}"
    err || return "${ERROR}"
    ;;
  esac
}

# do_build starts the build image process.
# Calls the correct build command/subcommand function
# Args: No args expected.
do_build() {

  local subcmd
  subcmd=$(PA_get_subcommand) || err || return
  case ${subcmd} in
  image)
    BI_sanity_checks || return
    BI_build_image
    ;;
  *)
    printf 'INTERNAL ERROR: This should not happen.' >"${STDERR}"
    err || return "${ERROR}"
    ;;
  esac
}

# sanity_checks is expected to run some quick and simple checks to
# see if key components are available.
# Args: No args expected.
sanity_checks() {

  local binary

  for binary in tac column tput grep sed; do
    if ! command -v "${binary}" >&/dev/null; then
      printf 'ERROR: "%s" binary not found in path. Aborting.' "${binary}" \
        >"${STDERR}"
      return "${ERROR}"
    fi
  done

  # Disable terminal escapes (colours) if stdout is not a terminal
  [ -t 1 ] || UT_disable_colours
}

# Calls main() if we're called from the command line
if [ "$0" = "${BASH_SOURCE[0]}" ] || [ -z "${BASH_SOURCE[0]}" ]; then
  main "$@"
fi

# vim helpers -----------------------------------------------------------------
#include globals.sh
# vim:ft=sh:sw=2:et:ts=2:
