# MAIN - execution starts here

# Declare externally defined variables ----------------------------------------

# Defined in GL (globals.sh)
declare OK ERROR STOP STDERR

# main is the start point for this application.
main() {

  init || return

  trap cleanup EXIT

  local retval="${OK}"

  sanity_checks || return

  parse_options "$@" || retval=$?
  if [[ ${retval} -eq ${ERROR} ]]; then
    return "${ERROR}"
  elif [[ ${retval} -eq ${STOP} ]]; then
    return "${OK}"
  fi

  case $(PA_get_command) in
  create) do_create ;;
  delete) do_delete ;;
  build) do_build ;;
  get) do_get ;;
  exec) do_exec ;;
  *)
    printf 'INTERNAL ERROR: This should not happen.'
    err || return "${ERROR}"
    ;;
  esac
}

init() {
  GL_init || return
  UT_init || return
  CT_init || return
}

# cleanup is called from an EXIT trap only, when the program exits.
# It calls the cleanup functions from other 'modules'.
cleanup() {

  # Called when the script exits.

  UT_cleanup
  BI_cleanup

  return "${OK}"
}

# do_create chooses which function to run for 'create SUBCOMMAND'.
# Args: None expected.
do_create() {

  # Calls the correct command/subcommand function

  case $(PA_get_subcommand) in
  cluster)
    CC_sanity_checks || return
    CC_cluster_create
    ;;
  *)
    printf 'INTERNAL ERROR: This should not happen.'
    err || return "${ERROR}"
    ;;
  esac
}

# do_build starts the build image process.
# Calls the correct build command/subcommand function
# Args: None expected.
do_build() {

  case $(PA_get_subcommand) in
  image)
    BI_sanity_checks || return
    BI_build_image
    ;;
  *)
    printf 'INTERNAL ERROR: This should not happen.'
    err || return "${ERROR}"
    ;;
  esac
}

# ---------------------------------------------------------------------------
sanity_checks() {

  # Check our environment
  # No args expected

  local binary

  for binary in tac column tput grep sed; do
    if ! command -v "$binary" >&/dev/null; then
      printf 'ERROR: "%s" binary not found in path. Aborting.' "$binary" >"$E"
      return 1
    fi
  done

  # Disable terminal escapes (colours) if stdout is not a terminal
  [ -t 1 ] || {
    colgreen=
    colred=
    colyellow=
    colreset=
    success="✓"
    probablysuccess="$success"
    failure="✕"
  }
}

# Calls main() if we're called from the command line
if [ "$0" = "${BASH_SOURCE[0]}" ] || [ -z "${BASH_SOURCE[0]}" ]; then
  main "$@"
fi

# vim:ft=sh:sw=2:et:ts=2:
