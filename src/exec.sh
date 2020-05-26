# EX - EXec

# EX is an associative array that holds data specific to the get cluster command.
#declare -A EX

# Declare externally defined variables ----------------------------------------

declare OK ERROR STDERR TRUE FALSE

# Getters/Setters -------------------------------------------------------------

# Public Functions ------------------------------------------------------------

# EX_process_options checks if arg1 is in a list of valid exec options. This
# function is called by the parser.
# Args: arg1 - the option to check.
#       arg2 - value of the item to be set, optional
EX_process_options() {

  # Args:
  #   arg1 - The option to check.

  local opt validopts=(
    "--help"
    "-h"
  )

  for opt in "${validopts[@]}"; do
    [[ $1 == "${opt}" ]] && return
  done

  _PA_usage
  printf 'ERROR: "%s" is not a valid "get cluster" option.\n' "$1" \
    >"${STDERR}"
  return "${ERROR}"
}

# EX_usage outputs help text for the create exec component.
# It is called by PA_usage().
# Args: None expected.
EX_usage() {

  cat <<'EnD'
EXEC has no subcommands. Exec into a container.
 
exec options:
 
 Format:
  exec [NAME]
  NAME        - (optional) The name of the container to log into.
                If this option is empty then the user will be offered
                a choice of containers to log in to. If there is only
                one cluster and one node then NAME can be left empty
                and it will log into the only available container.

EnD
}

EX_new() {
  # Program the parser's state machine
  PA_add_state_callback "COMMAND" "exec" "ARG1" ""
  PA_add_state_callback "ARG1" "exec" "END" "EX_set_containername"
  # Set up the parser's option callbacks
  PA_add_option_callback "exec" "EX_process_options" || return
  PA_add_usage_callback "exec" "EX_usage" || return
}

# ---------------------------------------------------------------------------
EX_run() {

  _EX_sanity_checks || return

  # Execs into the container referenced by arg1. If just 'mokctl exec' is
  # called without options then the user is offered a selection of existing
  # clusters to exec into.
  #
  # Args
  #  arg1 - Full name of container

  local names int ans lines containernames

  GC_set_showheader "${FALSE}" || err || return
  names=$(GC_run) || return
  names=$(printf '%s' "${names}" | awk '{ print $3; }')
  readarray -t containernames <<<"${names}"

  if [[ -n $1 ]]; then

    # The caller gave a specific name for exec.
    # Check if the container name exists

    if grep -qs "^$1$" <<<"${names}"; then
      _EX_exec "$1" || return
      return "${OK}"
    else
      printf 'ERROR: Cannot exec into non-existent container: "%s".\n' \
        "$1"
      return "${ERROR}"
    fi

  elif [[ ${#containernames[*]} == 1 ]]; then

    # If there's only one container just log into it without asking
    _EX_exec "${containernames[0]}"

  else

    # The caller supplied no container name.
    # Present some choices

    printf 'Choose the container to log in to:\n\n'

    GC_set_showheader "${TRUE}" || err || return
    readarray -t lines <<<"$(do_get_clusters_nomutate)" || return

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

    _EX_exec "${containernames[ans - 1]}"
  fi
}

# EX_sanity_checks is expected to run some quick and simple checks to
# see if it has all it's key components. For exec this does nothing.
# Args: None expected.
_EX_sanity_checks() { :; }

# ---------------------------------------------------------------------------
_EX_exec() {

  # Exec into the docker container
  # Args:
  #   arg1 - docker container name
  #   arg2 - command to run

  local cmd=${2:-bash}

  containerrt=$(CU_containerrt) || err || return

  read -rt 0.1
  if [[ ${containerrt} == "podman" ]]; then
    exec podman exec -ti "$1" "${cmd}"
  elif [[ ${containerrt} == "podman" ]]; then
    exec docker exec -ti "$1" "${cmd}"
  fi
}

# Initialise EX
EX_new

# vim helpers -----------------------------------------------------------------
#include globals.sh
# vim:ft=sh:sw=2:et:ts=2:
