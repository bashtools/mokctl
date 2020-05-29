# PA - PArser

# _PA holds data specific to parsing the command line arguments.
declare -A _PA

# Declare externally defined variables ----------------------------------------

# Defined in ER (globals.sh)
declare OK ERROR STDERR

# Getters/Setters -------------------------------------------------------------

# PA_command getter outputs the _PA[command] array member. This contains the
# command the user requested.
PA_command() {
  printf '%s' "${_PA[command]}"
}

# PA_subcommand getter outputs the _PA[subcommand] array member. This contains
# the subcommand the user requested.
PA_subcommand() {
  printf '%s' "${_PA[subcommand]}"
}

# PA_shift outputs the _PA[shift] array member, returned by the caller
# when an extra shift is required whilst consuming option values.
#
# Example code:
# ```
#XX_process_options_callback() {
#
#  case "$1" in
#  -h | --help)
#    CC_usage
#    return "${STOP}"
#    ;;
#    ... omitted ...
#  --k8sver)
#    _CC[k8sver]="$2"
#    return "$(PA_shift)"
#    ;;
#  --with-lb)
#    ... omitted ..
# ```
PA_shift() {
  printf '%s' "${_PA[shift]}"
}

# PA_set_state setter sets the initial state of the parser, which should be one
# of COMMAND, SUBCOMMAND, or ARG1.
# Args: arg1 - the initial state to set.
PA_set_state() {
  _PA[state]="$1"
}

# Public Functions ------------------------------------------------------------

# PA_add_option_callback adds a callback to the list of callbacks used for
# processing options.
# Args: arg1 - Null string (for global options), COMMAND or COMMANDSUBCOMMAND.
#       arg2 - The function to call.
PA_add_option_callback() {
  _PA[optscallbacks]+="$1,$2 "
}

# PA_add_usage_callback adds a callback to the list of callbacks used for
# output of help text.
# Args: arg1 - Null string (for global help), COMMAND or COMMANDSUBCOMMAND.
#       arg2 - The function to call.
PA_add_usage_callback() {
  _PA[usagecallbacks]+="$1,$2 "
}

# PA_add_state adds a callback to the list of callbacks used for
# programming the state machine.
# Args: arg1 - Current state to match.
#       arg2 - The value of the state to match.
#       arg3 - The new state if arg1 and arg2 match.
#       arg4 - The function to call, optional.
PA_add_state() {
  _PA[statecallbacks]+="$1,$2,$3,$4 "
}

# PA_run implements an interleaved state machine to process the
# user request. It allows for strict checking of arguments and args. All
# command line arguments are processed in order from left to right.
#
# Each COMMAND can have a different set of requirements which are controlled
# by setting the next state at each transition.
#
# --global-options COMMAND --command-options SUBCOMMAND --subcommand-options \
#  ARG1 --subcommand-options ARG2 --subcommand-options ...
#
# --global-options are those before COMMAND.
# --command-options can be after the COMMAND but before SUBCOMMAND.
# --subcommand-options can be anywhere after the SUBCOMMAND.
#
# Args: arg1-N - The arguments given to mokctl by the user on the command line
PA_run() {

  set -- "$@"
  local ARGN=$# ARGNUM=0 retval=0
  while [ "${ARGN}" -ne 0 ]; do
    case "$1" in
    --* | -*)
      _PA_process_option "$1" "$2" || {
        retval=$?
        if [[ ${retval} == "${_PA[shift]}" ]]; then
          ARGN=$((ARGN - 1))
          shift
        else
          return "${retval}"
        fi
      }
      ;;
    *)
      case "${_PA[state]}" in
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
          printf 'Invalid SUBCOMMAND for %s, "%s".\n\n' "${_PA[command]}" "${1}" \
            >"${STDERR}"
          return "${ERROR}"
        }
        ;;
      ARG*)
        ((ARGNUM++))
        _PA_check_token "${1}" "ARG${ARGNUM}"
        [[ $? -eq ${ERROR} ]] && {
          _PA_usage
          printf 'Invalid ARG1 for %s %s, "%s".\n\n' "${_PA[command]}" \
            "${_PA[subcommand]}" "${1}" >"${STDERR}"
          return "${ERROR}"
        }
        ;;
      END)
        _PA_usage
        printf 'ERROR No more args expected, "%s" is unexpected for "%s %s"\n' \
          "${1}" "${_PA[command]}" "${_PA[subcommand]}" >"${STDERR}"
        return "${ERROR}"
        ;;
      *)
        printf 'Internal ERROR. Invalid state "%s"\n' "${_PA[state]}" >"${STDERR}"
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

# PA_new sets the initial values for the PArser's associative array.
# Args: None expected.
_PA_new() {
  _PA[command]=
  _PA[subcommand]=
  _PA[state]="COMMAND"
  _PA[optscallbacks]=
  _PA[usagecallbacks]=
  # The return value if the caller asked for an extra shift:
  _PA[shift]=3
}

# _PA_check_token checks for a valid token in arg2 state. The logic is
# most easily understood by reading the full original version at:
# https://github.com/mclarkson/my-own-kind/blob/master/docs/package.md#scripted-cluster-creation-and-deletion
# This function is a reduction of all the check_xxx_token functions.
# Args: arg1 - the token to check.
#       arg2 - the current state.
#       arg3 - the state value to set, optional. This should only be sent
#              for command and subcommand states.
_PA_check_token() {

  local item

  if [[ -n ${_PA[subcommand]} ]]; then
    cmdsubcommand="${_PA[command]}${_PA[subcommand]}"
  elif [[ -n ${_PA[command]} && ${_PA[state]} != "ARG"* ]]; then
    cmdsubcommand="${_PA[command]}$1"
  elif [[ -n ${_PA[command]} && ${_PA[state]} == "ARG"* ]]; then
    cmdsubcommand="${_PA[command]}"
  elif [[ -z ${_PA[command]} && ${_PA[state]} == "ARG"* ]]; then
    cmdsubcommand=
  else
    cmdsubcommand="$1"
  fi

  for item in ${_PA[statecallbacks]}; do
    IFS=, read -r state component newstate func <<<"${item}"
    [[ ${state} == "$2" ]] && {
      [[ ${component} == "${cmdsubcommand}" ]] && {
        [[ -n $3 ]] && _PA["$3"]="$1"
        _PA[state]="${newstate}"
        [[ -n ${func} ]] && {
          eval "${func} $1" || return
        }
        return "${OK}"
      }
    }
  done
}

# _PA_process_option checks that the user-provided option is valid for the
# command-subcommand or global states.
# Args: arg1 - The option to check.
#       arg2 - TODO The value of the option if present, optional.
_PA_process_option() {

  local item curcmdsubcmd

  curcmdsubcmd="${_PA[command]}${_PA[subcommand]}"

  for item in ${_PA[optscallbacks]}; do
    IFS=, read -r cmdsubcmd func <<<"${item}"
    [[ ${curcmdsubcmd} == "${cmdsubcmd}" ]] && {
      eval "${func} \"$1\" \"$2\""
      return $?
    }
  done

  return "${ERROR}"
}

# _PA_usage outputs help text for a single component if help was asked for when
# a command was specified, or for all components otherwise.
# Args: None expected.
_PA_usage() {

  curcmdsubcmd="${_PA[command]}${_PA[subcommand]}"

  for item in ${_PA[usagecallbacks]}; do
    IFS=, read -r cmdsubcmd func <<<"${item}"
    [[ ${curcmdsubcmd} == "${cmdsubcmd}" ]] && {
      eval "${func}"
      return
    }
  done

  eval "${_PA[usage]}"
}

# Initialise _PA
_PA_new

# vim helpers -----------------------------------------------------------------
#include globals.sh
# vim:ft=sh:sw=2:et:ts=2:
