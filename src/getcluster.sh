# GC - Get Cluster

# _GC is an associative array that holds data specific to the get cluster command.
declare -A _GC

# Declare externally defined variables ----------------------------------------

declare OK ERROR STDERR TRUE STOP

# Getters/Setters -------------------------------------------------------------

GC_showheader() {
  printf '%s' "${_GC[showheader]}"
}

GC_set_showheader() {
  _GC[showheader]="$1"
}

GC_set_clustername() {
  _GC[clustername]="$1"
}

# Public Functions ------------------------------------------------------------

GC_cleanup() {
  :
}

# GC_process_options checks if arg1 is in a list of valid get cluster
# options. This function is called by the parser.
# Args: arg1 - the option to check.
#       arg2 - value of the item to be set, optional
GC_process_options() {

  case "$1" in
  -h | --help)
    GC_usage
    return "${STOP}"
    ;;
  *)
    GC_usage
    printf 'ERROR: "%s" is not a valid "build" option.\n' "${1}" \
      >"${STDERR}"
    return "${ERROR}"
    ;;
  esac
}

# GC_usage outputs help text for the create cluster component.
# It is called by PA_usage().
# Args: None expected.
GC_usage() {

  cat <<'EnD'
GET subcommands are:
 
  cluster(s) - list all mokctl managed clusters.
 
get cluster(s) options:
 
 Format:
  get cluster(s) [NAME]
  NAME        - (optional) The name of the cluster to get
                details about.

EnD
}

# GC_run gets information about cluster(s).
# This function is called in main.sh.
# Args: None expected.
GC_run() {

  _GC_sanity_checks || return

  local ids id info output labelkey
  local containerhostname containerip

  declare -a nodes

  ids=$(CU_get_cluster_container_ids "${_GC[clustername]}") || return

  if [[ -z ${ids} ]]; then
    return "${OK}"
  fi

  readarray -t nodes <<<"${ids}"

  # Use 'docker inspect' to get the value of the label $LABELKEY

  output=$(mktemp -p /var/tmp) || {
    printf 'ERROR: mktmp failed.\n' >"${STDERR}"
    return "${ERROR}"
  }

  # Output the header
  [[ ${_GC[showheader]} -eq ${TRUE} ]] && {
    printf 'MOK_Cluster Docker_ID Container_Name IP_Address\n' >"${output}"
  }

  labelkey=$(CU_labelkey) || err || return

  for id in "${nodes[@]}"; do

    info=$(CU_get_container_info "${id}") || return

    clustname=$(JSONPath ".[0].Config.Labels.${labelkey}" -b <<<"${info}") ||
      err || return

    containerhostname=$(JSONPath '.[0].Config.Hostname' -b <<<"${info}") ||
      err || return

    containerip=$(JSONPath '.[0].NetworkSettings.IPAddress' -b <<<"${info}") ||
      err || return

    printf '%s %s %s %s\n' "${clustname}" "${id}" "${containerhostname}" "${containerip}"

  done | sort -k 3 >>"${output}"

  column -t "${output}" || err
}

# _GC_new sets the initial values for the _GC associative array.
# This function is called by main().
# Args: None expected.
_GC_new() {
  _GC[showheader]="${TRUE}"

  # Program the parser's state machine
  PA_add_state "COMMAND" "get" "SUBCOMMAND" ""
  PA_add_state "SUBCOMMAND" "getcluster" "ARG1" ""
  PA_add_state "ARG1" "getcluster" "END" "GC_set_clustername"

  # Set up the parser's option callbacks
  PA_add_option_callback "get" "GC_process_options" || return
  PA_add_option_callback "getcluster" "GC_process_options" || return

  # Set up the parser's usage callbacks
  PA_add_usage_callback "get" "GC_usage" || return
  PA_add_usage_callback "getcluster" "GC_usage" || return
}

# GC_sanity_checks is expected to run some quick and simple checks to
# see if it has all it's key components. For build image this does nothing.
# This function should not be deleted as it is called in main.sh.
# Args: None expected.
_GC_sanity_checks() { :; }

# Initialise _GC
_GC_new

# vim helpers -----------------------------------------------------------------
#include globals.sh
# vim:ft=sh:sw=2:et:ts=2:
