# EX - EXec

# EX is an associative array that holds data specific to the get cluster command.
declare -A _EX

# Declare externally defined variables ----------------------------------------

declare OK ERROR STDERR TRUE STOP

# Getters/Setters -------------------------------------------------------------

# EX_set_containername setter sets the containername to be used to 'log in' to.
EX_set_containername() {
  _EX[containername]="$1"
}

# Public Functions ------------------------------------------------------------

# EX_process_options checks if arg1 is in a list of valid exec options. This
# function is called by the parser, via a callback in _EX_new.
# Args: arg1 - the option to check.
#       arg2 - value of the item to be set, optional
EX_process_options() {

  case "$1" in
  -h | --help)
    EX_usage
    return "${STOP}"
    ;;
  *)
    EX_usage
    printf 'ERROR: "%s" is not a valid "build" option.\n' "${1}" \
      >"${STDERR}"
    return "${ERROR}"
    ;;
  esac
}

# EX_usage outputs help text for the create exec component.  It is called in
# this file and by PA_usage(), via a callback in _EX_new.
# Args: None expected.
EX_usage() {

  cat <<'EnD'
EXEC has no subcommands. Exec into a container.
 
exec options:
 
 Format:
  exec [NAME]
  NAME        - (optional) The name of the container to 'log in' to.
                If NAME is not given then the user will be offered
                a choice of containers to log in to. If there is only
                one cluster and one node then it will 'log in' to the
                only available container.

EnD
}

# Execs 'bash' in the container referenced by _EX[containername]. If just
# 'mokctl exec' is called without options then the user is offered a selection
# of existing clusters to exec into.
# Args: None expected.
# ---------------------------------------------------------------------------
EX_run() {

  _EX_sanity_checks || return

  local names int ans lines containernames gcoutput

  GC_set_showheader "${TRUE}" || err || return
  gcoutput=$(GC_run) || return
  names=$(printf '%s' "${gcoutput}" | awk '{ print $3; }')
  readarray -t containernames <<<"${names}"

  if [[ -n ${_EX[containername]} ]]; then

    # The caller gave a specific name for exec.
    # Check if the container name exists

    if grep -qs "^${_EX[containername]}$" <<<"${names}"; then
      _EX_exec "${_EX[containername]}" || return
      return "${OK}"
    else
      printf 'ERROR: Cannot exec into non-existent container: "%s".\n' \
        "${_EX[containername]}"
      return "${ERROR}"
    fi

  elif [[ ${#containernames[*]} == 2 ]]; then

    # If there's only one container just log into it without asking
    _EX_exec "${containernames[1]}"

  elif [[ ${#containernames[*]} == 1 ]]; then

    printf 'No containers found.\n'
    return "${OK}"

  else

    # The caller supplied no container name.
    # Present some choices

    printf 'Choose the container to log in to:\n\n'

    readarray -t lines <<<"${gcoutput}" || return

    # Print the header then print the items in the loop
    printf '   %s\n' "${lines[0]}"
    for int in $(seq 1 $((${#lines[*]} - 1))); do
      printf '%00d) %s\n' "${int}" "${lines[int]}"
    done | sort -k 4

    printf "\nChoose a number (Enter to cancel)> "
    read -r ans

    [[ -z ${ans} || ${ans} -lt 0 || ${ans} -gt $((${#lines[*]} - 1)) ]] && {
      printf '\nInvalid choice. Aborting.\n'
      return "${OK}"
    }

    _EX_exec "${containernames[ans]}"
  fi
}

# Private Functions -----------------------------------------------------------

# _EX_new sets the initial values for the _EX associative array and sets up the
# parser ready for processing the command line arguments, options and usage.
_EX_new() {
  _EX[containername]=

  # Program the parser's state machine
  PA_add_state "COMMAND" "exec" "ARG1" ""
  PA_add_state "ARG1" "exec" "END" "EX_set_containername"

  # Set up the parser's option callbacks
  PA_add_option_callback "exec" "EX_process_options" || return
  PA_add_usage_callback "exec" "EX_usage" || return
}

# EX_sanity_checks is expected to run some quick and simple checks to
# see if it has all it's key components. For exec this does nothing.
# Args: None expected.
_EX_sanity_checks() { :; }

# _EX_exec runs a command in a docker container using bash as the command by
# default.
# Args: arg1 - docker container name
#       arg2 - command to run
_EX_exec() {

  local cmd=${2:-bash}

  containerrt=$(CU_containerrt) || err || return

  read -rt 0.1
  if [[ ${containerrt} == "podman" ]]; then
    exec podman exec -ti "$1" "${cmd}"
  elif [[ ${containerrt} == "docker" ]]; then
    exec docker exec -ti "$1" "${cmd}"
  fi
}

# Initialise EX
_EX_new || exit 1

# vim helpers -----------------------------------------------------------------
#include globals.sh
# vim:ft=sh:sw=2:et:ts=2:
