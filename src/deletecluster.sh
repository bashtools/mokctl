# DC - Delete Cluster

# GE is an associative array that holds data specific to the get cluster command.
declare -A _DC

# Declare externally defined variables ----------------------------------------

declare OK ERROR STDERR STOP TRUE

# Getters/Setters -------------------------------------------------------------

# DC_set_clustername setter sets the cluster name to be deleted. This is
# called by the parser, via a callback in _DC_new.
DC_set_clustername() {
  _DC[clustername]="$1"
}

# Public Functions ------------------------------------------------------------

# DC_process_options checks if arg1 is in a list of valid delete cluster
# options. This function is called by the parser, via a callback in _DC_new.
# Args: arg1 - the option to check.
#       arg2 - value of the item to be set, optional
DC_process_options() {

  case "$1" in
  -h | --help)
    BI_usage
    return "${STOP}"
    ;;
  *)
    BI_usage
    printf 'ERROR: "%s" is not a valid "build" option.\n' "${1}" \
      >"${STDERR}"
    return "${ERROR}"
    ;;
  esac
}

# DC_usage outputs help text for the create cluster component.
# It is called by PA_usage(), via a callback in _DC_new.
# Args: None expected.
DC_usage() {

  cat <<'EnD'
DELETE subcommands are:
 
  cluster - Delete a local kubernetes cluster.
 
delete cluster options:
 
 Format:
  delete cluster NAME
  NAME        - The name of the cluster to delete

EnD
}

# DC_run starts the delete cluster process.
# Args: None expected.
DC_run() {

  _DC_sanity_checks || return

  # Mutate functions make system changes.

  declare -i numnodes=0
  local id ids r

  numnodes=$(CU_get_cluster_size "${_DC[clustername]}") || return

  [[ ${numnodes} -eq 0 ]] && {
    printf '\nERROR: No cluster exists with name, "%s". Aborting.\n\n' \
      "${_DC[clustername]}" >"${STDERR}"
    return "${ERROR}"
  }

  ids=$(CU_get_cluster_container_ids "${_DC[clustername]}") || return

  printf 'The following containers will be deleted:\n\n'

  GC_set_showheader "${TRUE}"
  GC_run "${_DC[clustername]}" || return

  printf "\nAre you sure you want to delete the cluster? (y/N) >"

  read -r ans

  [[ ${ans} != "y" ]] && {
    printf '\nCancelling by user request.\n'
    return "${OK}"
  }

  printf '\n'

  for id in ${ids}; do
    UT_run_with_progress \
      "    Deleting id, '${id}' from cluster '${_DC[clustername]}'." \
      _DC_delete "${id}"
    r=$?
    [[ ${r} -ne 0 ]] && {
      runlogfile=$(UT_runlogfile) || err || return
      cat "${runlogfile}" >"${STDERR}"
      printf '\nERROR: Docker failed.\n\n' >"${STDERR}"
      err
      return "${r}"
    }
  done

  printf '\n'
}

# Private Functions -----------------------------------------------------------

# _DC_new sets the initial values for the _DC associative array and sets up the
# parser ready for processing the command line arguments, options and usage.
# Args: None expected.
_DC_new() {
  _DC[clustername]=

  # Program the parser's state machine
  PA_add_state "COMMAND" "delete" "SUBCOMMAND" ""
  PA_add_state "SUBCOMMAND" "deletecluster" "ARG1" ""
  PA_add_state "ARG1" "deletecluster" "END" "DC_set_clustername"

  # Set up the parser's option callbacks
  PA_add_option_callback "delete" "DC_process_options" || return
  PA_add_option_callback "deletecluster" "DC_process_options" || return

  # Set up the parser's usage callbacks
  PA_add_usage_callback "delete" "DC_usage" || return
  PA_add_usage_callback "deletecluster" "DC_usage" || return
}

# DC_sanity_checks is expected to run some quick and simple checks to see if it
# has it's main requirements before DC_run is called.
# Args: None expected.
_DC_sanity_checks() {

  if [[ -z ${_DC[clustername]} ]]; then
    DC_usage
    printf 'Please provide the Cluster NAME to delete.\n' >"${STDERR}"
    return "${ERROR}"
  fi
}

# _DC_delete stops and removes a docker container.
# Args: arg1 - docker id to delete.
_DC_delete() {

  docker stop -t 5 "${id}"
  docker rm "${id}" || err
}

# Initialise _DC
_DC_new || exit 1

# vim helpers -----------------------------------------------------------------
#include globals.sh
# vim:ft=sh:sw=2:et:ts=2:
