# GE - GEt cluster

# GE is an associative array that holds data specific to the get cluster command.
declare -A GE

# Declare externally defined variables ----------------------------------------

declare OK ERROR STDERR

# Getters/Setters -------------------------------------------------------------

# Public Functions ------------------------------------------------------------

# GE_init sets the initial values for the GE associative array.
# This function is called by main().
# Args: None expected.
CU_init() {

  GE[dummy]=
}

CU_cleanup() {
  :
}

# ---------------------------------------------------------------------------
GE_check_valid_options() {

  # Args:
  #   arg1 - The option to check.

  local opt validopts=(
    "--help"
    "-h"
  )

  for opt in "${validopts[@]}"; do
    [[ $1 == "${opt}" ]] && return
  done

  GE_usage
  printf 'ERROR: "%s" is not a valid "get cluster" option.\n' "$1" >"${STDERR}"
  return "${ERROR}"
}

# ---------------------------------------------------------------------------
GE_usage() {

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

# ---------------------------------------------------------------------------
do_get() {

  # Calls the correct command/subcommand function

  case $SUBCOMMAND in
  cluster)
    do_get_clusters_sanity_checks || return
    do_get_clusters_nomutate "$GET_CLUSTER_NAME"
    ;;
  esac
}

# ---------------------------------------------------------------------------
do_get_clusters_sanity_checks() {

  # No sanity checks required.
  # Globals: None
  # No args expected

  :
}

# ---------------------------------------------------------------------------
do_get_clusters_nomutate() {

  # Mutate functions make system changes but this one doesn't and I don't
  #  know where to put it yet.
  # Gets cluster details
  # Globals: None
  # Args
  #   arg1 - cluster name, optional

  local ids id info clustname=$1 output
  local containerhostname containerip

  declare -a nodes

  ids=$(CU_get_cluster_docker_ids "${clustname}") || return

  if [[ -z ${ids} ]]; then
    return "${OK}"
  fi

  readarray -t nodes <<<"$ids"

  # Use 'docker inspect' to get the value of the label $LABELKEY

  output=$(mktemp -p /var/tmp) || {
    printf 'ERROR: mktmp failed.\n' >"$E"
    return $ERROR
  }

  # Output the header
  [[ $GET_CLUSTER_SHOW_HEADER -eq $TRUE ]] && {
    printf 'MOK_Cluster Docker_ID Container_Name IP_Address\n' >"$output"
  }

  for id in "${nodes[@]}"; do

    info=$(CU_get_container_info "$id") || return

    clustname=$(sed -rn \
      '/Labels/,/}/ {s/[":,]//g; s/^ *'"$LABELKEY"' ([^ ]*).*/\1/p }' \
      <<<"$info") || err || return

    containerhostname=$(sed -rn \
      '/"Config"/,/}/ {s/[":,]//g; s/^ *Hostname ([^ ]*).*/\1/p }' \
      <<<"$info") || err || return

    containerip=$(sed -rn \
      '/NetworkSettings/,/Networks/ {s/[":,]//g; s/^ *IPAddress ([^ ]*).*/\1/p }' \
      <<<"$info") || err || return

    printf '%s %s %s %s\n' "$clustname" "$id" "$containerhostname" "$containerip"

  done | sort -k 3 >>"$output"

  column -t "$output" || err
}

# ---------------------------------------------------------------------------
get_mok_cluster_docker_ids() {

  # Use 'docker ps .. label= ..' to get a list of mok clusters
  # Args
  #   arg1 - mok cluster name, optional

  docker ps -a -f label="$LABELKEY$1" -q || {
    printf 'ERROR: docker failed\n' >"$E"
    err || return
  }
}

# vim helpers -----------------------------------------------------------------
#include globals.sh
# vim:ft=sh:sw=2:et:ts=2:
