# shellcheck shell=bash disable=SC2148
# MA - execution starts here

# Defined in GL (globals.sh)
declare OK ERROR STOP STDERR TRUE

# main is the start point for this application.
# Args: arg1-N - the command line arguments entered by the user.
MA_main() {

  trap MA_cleanup EXIT
  MA_sanity_checks || return
  MA_register_parser_global_options || return

  local retval="${OK}"
  PA_run "$@" || retval=$?
  if [[ ${retval} -eq ${ERROR} ]]; then
    return "${ERROR}"
  elif [[ ${retval} -eq ${STOP} ]]; then
    return "${OK}"
  fi

  local cmd subcmd
  cmd=$(PA_command) || err || return
  subcmd=$(PA_subcommand) || err || return
  case "${cmd}${subcmd}" in
  create | createcluster) CC_run ;;
  delete | deletecluster) DC_run ;;
  build | buildimage) BI_run ;;
  get | getcluster | getclusters) GC_run ;;
  exec) EX_run ;;
  *)
    PA_usage
    printf '\nERROR: No COMMAND specified.\n'
    ;;
  esac
}

# MA_register_parser_global_options adds the options callback and usage
# callback to the Parser.
MA_register_parser_global_options() {
  PA_add_option_callback "" "MA_process_global_options"
  PA_add_usage_callback "" "MA_usage"
}

# MA_process_global_options is called by the parser when a global option is
# encountered for processing.
# Args: arg1 - the global option that was found.
MA_process_global_options() {
  case "$1" in
  -h | --help)
    PA_usage
    return "${STOP}"
    ;;
  -p | --plain)
    UT_set_plain "${TRUE}"
    ;;
  *)
    printf 'INTERNAL ERROR: Invalid global option, "%s".' "$1"
    return "${ERROR}"
    ;;
  esac
}

# MA_cleanup is called from an EXIT trap only, when the program exits, and
# calls every other function matching the pattern '^.._cleanup'.
# Args: No args expected.
MA_cleanup() {
  local retval="${OK}" funcs func
  funcs=$(declare -F | awk '{print $NF;}' | grep '^.._cleanup')
  for func in ${funcs}; do
    [[ ${func} == "${FUNCNAME[0]}" ]] && continue
    eval "${func}" || retval=$?
  done
  return "${retval}"
}

# MA_sanity_checks is expected to run some quick and simple checks to
# see if key components are available before MA_main is called.
# Args: No args expected.
MA_sanity_checks() {

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

# MA_usage outputs help text for all components then quits with no error.  This
# is registered as a callback in the Parser in
# MA_register_parser_global_options.
# Args: None expected.
MA_usage() {

  cat <<'EnD'
Usage: mokctl [-h] <command> [subcommand] [ARGS...]
 
Global options:
  --help
  -h     - This help text
  --plain
  -p     - Plain output. No colours or animations.
 
Where command can be one of:
  create - Add item(s) to the system.
  delete - Delete item(s) from the system.
  build  - Build item(s) used by the system.
  get    - Get details about items in the system.
  exec   - 'Log in' to the container.

For help on a specific command, run:
  mokctl <command> --help
EnD
}

# vim helpers -----------------------------------------------------------------
#include globals.sh
# vim:ft=sh:sw=2:et:ts=2:
