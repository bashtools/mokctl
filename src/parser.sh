# PA - PArser

# PA holds data specific to parsing the command line arguments.
declare -A PA

# Declare externally defined variables ----------------------------------------

# Defined in ER (globals.sh)
declare OK ERROR STDERR

# Getters/Setters -------------------------------------------------------------

# PA_command outputs the PA[command] array member. This contains the command
# the user requested.
PA_command() {
  printf '%s' "${PA[command]}"
}

# PA_subcommand outputs the PA[subcommand] array member. This contains the
# subcommand the user requested.
PA_subcommand() {
  printf '%s' "${PA[subcommand]}"
}

# Public Functions ------------------------------------------------------------

# PA_add_option_callback adds a callback to the list of callbacks used for
# processing options.
# Args: arg1 - Null string (for global options), COMMAND or COMMANDSUBCOMMAND.
#       arg2 - The function to call.
PA_add_option_callback() {
  PA[optscallbacks]+="$1,$2 "
}

# PA_add_usage_callback adds a callback to the list of callbacks used for
# output of help text.
# Args: arg1 - Null string (for global help), COMMAND or COMMANDSUBCOMMAND.
#       arg2 - The function to call.
PA_add_usage_callback() {
  PA[usagecallbacks]+="$1,$2 "
}

# PA_add_state adds a callback to the list of callbacks used for
# programming the state machine.
# Args: arg1 - Current state to match.
#       arg2 - The value of the state to match.
#       arg3 - The new state if arg1 and arg2 match.
#       arg4 - The function to call, optional.
PA_add_state() {
  PA[statecallbacks]+="$1,$2,$3,$4 "
}

# PA_new sets the initial values for the PArser's associative array.
# Args: None expected.
PA_new() {
  PA[command]=
  PA[subcommand]=
  PA[state]="COMMAND"
  PA[optscallbacks]=
  PA[usagecallbacks]=
}

# PA_parse_args implements an interleaved state machine to process the
# user request. It allows for strict checking of arguments and args. All
# command line arguments are processed in order from left to right.
#
# Each COMMAND can have a different set of requirements which are controlled
# by setting the next state at each transition.
#
# --global-options COMMAND --command-options SUBCOMMAND --subcommand-options \
#  ARG1 ARG2 ARG3 ...
#
# --global-options are those before COMMAND.
# --command-options can be anywhere after the SUBCOMMAND.
# --subcommand-options can be anywhere after the SUBCOMMAND.
#
# Args: arg1-N - The arguments given to mokctl by the user on the command line
PA_parse_args() {

  set -- "$@"
  local ARGN=$#
  while [ "${ARGN}" -ne 0 ]; do
    case "$1" in
    --* | -*)
      _PA_process_option "$1" || return "$?"
      ;;
    *)
      case "${PA[state]}" in
      COMMAND)
        _PA_check_token "${1}" "COMMAND" "command"
        [[ $? -eq ${ERROR} ]] && {
          _PA_usage
          printf 'Invalid COMMAND, "%s".\n\n' "$1" >"${STDERR}"
          return "${ERROR}"
        }
        ;;
      SUBCOMMAND)
        _PA_check_token "$1" "SUBCOMMAND" "subcommand"
        [[ $? -eq ${ERROR} ]] && {
          _PA_usage
          printf 'Invalid SUBCOMMAND for %s, "%s".\n\n' "${PA[command]}" "${1}" \
            >"${STDERR}"
          return "${ERROR}"
        }
        ;;
      ARG1)
        _PA_check_token "${1}" "ARG1"
        [[ $? -eq ${ERROR} ]] && {
          _PA_usage
          printf 'Invalid ARG1 for %s %s, "%s".\n\n' "${PA[command]}" \
            "${PA[subcommand]}" "${1}" >"${STDERR}"
          return "${ERROR}"
        }
        ;;
      ARG2)
        _PA_check_token "${1}" "ARG2"
        [[ $? -eq ${ERROR} ]] && {
          _PA_usage
          printf 'Invalid ARG for %s %s, "%s".\n\n' "${PA[command]}" \
            "${PA[subcommand]}" "${1}" >"${STDERR}"
          return "${ERROR}"
        }
        ;;
      ARG3)
        _PA_check_token "${1}" "ARG3"
        [[ $? -eq ${ERROR} ]] && {
          _PA_usage
          printf 'Invalid ARG for %s %s, "%s".\n\n' "${PA[command]}" \
            "${PA[subcommand]}" "${1}" >"${STDERR}"
          return "${ERROR}"
        }
        ;;
      ARG4)
        _PA_check_token "${1}" "ARG3"
        [[ $? -eq ${ERROR} ]] && {
          _PA_usage
          printf 'Invalid ARG for %s %s, "%s".\n\n' "${PA[command]}" \
            "${PA[subcommand]}" "${1}" >"${STDERR}"
          return "${ERROR}"
        }
        ;;
      ARG5)
        _PA_check_token "${1}" "ARG3"
        [[ $? -eq ${ERROR} ]] && {
          _PA_usage
          printf 'Invalid ARG for %s %s, "%s".\n\n' "${PA[command]}" \
            "${PA[subcommand]}" "${1}" >"${STDERR}"
          return "${ERROR}"
        }
        ;;
      ARG6)
        _PA_check_token "${1}" "ARG3"
        [[ $? -eq ${ERROR} ]] && {
          _PA_usage
          printf 'Invalid ARG for %s %s, "%s".\n\n' "${PA[command]}" \
            "${PA[subcommand]}" "${1}" >"${STDERR}"
          return "${ERROR}"
        }
        ;;
      END)
        _PA_usage
        printf 'ERROR No more args expected, "%s" is unexpected for "%s %s"\n' \
          "${1}" "${PA[command]}" "${PA[subcommand]}" >"${STDERR}"
        return "${ERROR}"
        ;;
      *)
        printf 'Internal ERROR. Invalid state "%s"\n' "${PA[state]}" >"${STDERR}"
        return "${ERROR}"
        ;;
      esac
      ;;
    esac
    shift 1
    ARGN=$((ARGN - 1))
  done

  return "${OK}"
}

# Private Functions -----------------------------------------------------------

# _PA_check_token checks for a valid token in arg2 state.
# Args: arg1 - the token to check.
#       arg2 - the current state.
#       arg3 - the state value to set, optional. This should only be sent
#              for command and subcommand states.
_PA_check_token() {

  local item

  if [[ -n ${PA[subcommand]} ]]; then
    cmdsubcommand="${PA[command]}${PA[subcommand]}"
  elif [[ -n ${PA[command]} && ${PA[state]} != "ARG"* ]]; then
    cmdsubcommand="${PA[command]}$1"
  elif [[ -n ${PA[command]} && ${PA[state]} == "ARG"* ]]; then
    cmdsubcommand="${PA[command]}"
  else
    cmdsubcommand="$1"
  fi

  for item in ${PA[statecallbacks]}; do
    IFS=, read -r state component newstate func <<<"${item}"
    [[ ${state} == "$2" ]] && {
      [[ ${component} == "${cmdsubcommand}" ]] && {
        [[ -n $3 ]] && PA["$3"]="$1"
        PA[state]="${newstate}"
        [[ -n ${func} ]] && {
          eval "${func} $1" || return
        }
        return "${OK}"
      }
    }
  done
}

# _PA_process_option checks that the sent option is valid for the
# command-subcommand or global options.
# Args: arg1 - The option to check.
#       arg2 - TODO The value of the option if present, optional.
_PA_process_option() {

  local item curcmdsubcmd

  curcmdsubcmd="${PA[command]}${PA[subcommand]}"

  for item in ${PA[optscallbacks]}; do
    IFS=, read -r cmdsubcmd func <<<"${item}"
    [[ ${curcmdsubcmd} == "${cmdsubcmd}" ]] && {
      eval "${func} $1"
      return
    }
  done

  return "${ERROR}"
}

# _PA_usage outputs help text for a single component if help was asked for when
# a command was specified, or for all components otherwise.
# Args: None expected.
_PA_usage() {

  curcmdsubcmd="${PA[command]}${PA[subcommand]}"

  for item in ${PA[usagecallbacks]}; do
    IFS=, read -r cmdsubcmd func <<<"${item}"
    [[ ${curcmdsubcmd} == "${cmdsubcmd}" ]] && {
      eval "${func}"
      return
    }
  done

  eval "${PA[usage]}"
}

# Initialise PA
PA_new

# vim helpers -----------------------------------------------------------------
#include globals.sh
# vim:ft=sh:sw=2:et:ts=2:
