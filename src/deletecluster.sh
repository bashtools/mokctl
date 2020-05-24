# ---------------------------------------------------------------------------
DC_check_valid_options() {

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
  printf 'ERROR: "%s" is not a valid "delete cluster" option.\n' "$1" \
    >"${STDERR}"
  return "${ERROR}"
}

# ---------------------------------------------------------------------------
delete_usage() {

  cat <<'EnD'
DELETE subcommands are:
 
  cluster - Delete a local kubernetes cluster.
 
delete cluster options:
 
 Format:
  delete cluster NAME
  NAME        - The name of the cluster to delete

EnD
}

# ---------------------------------------------------------------------------
do_delete() {

  # Calls the correct command/subcommand function
  # No args expected

  case $SUBCOMMAND in
  cluster)
    do_delete_cluster_sanity_checks || return
    do_delete_cluster_mutate
    ;;
  esac
}

# ---------------------------------------------------------------------------
do_delete_cluster_sanity_checks() {

  # Deletes a mok cluster. All user vars have been parsed and saved.
  # Globals: DELETE_CLUSTER_NAME
  # No args expected

  if [[ -z $DELETE_CLUSTER_NAME ]]; then
    usage
    printf 'Please provide the Cluster NAME to delete.\n' >"$E"
    return $ERROR
  fi
}

# ---------------------------------------------------------------------------
do_delete_cluster_mutate() {

  # Mutate functions make system changes.

  declare -i numnodes=0
  local id ids r

  numnodes=$(get_cluster_size "$DELETE_CLUSTER_NAME") || return

  [[ $numnodes -eq 0 ]] && {
    printf '\nERROR: No cluster exists with name, "%s". Aborting.\n\n' \
      "$DELETE_CLUSTER_NAME" >"$E"
    return $ERROR
  }

  ids=$(get_docker_ids_for_cluster "$DELETE_CLUSTER_NAME") || return

  printf 'The following containers will be deleted:\n\n'

  do_get_clusters_nomutate "$DELETE_CLUSTER_NAME" || return

  printf "\nAre you sure you want to delete the cluster? (y/N) >"

  read -r ans

  [[ $ans != "y" ]] && {
    printf '\nCancelling by user request.\n'
    return $OK
  }

  printf '\n'

  for id in $ids; do
    UT_run_with_progress \
      "    Deleting id, '$id' from cluster '$DELETE_CLUSTER_NAME'." \
      delete_docker_container "$id"
    r=$?
    [[ $r -ne 0 ]] && {
      cat "$RUNWITHPROGRESS_OUTPUT"
      printf '\nERROR: Docker failed.\n\n' >"$E"
      err
      return $r
    }
  done

  printf '\n'
}

# ---------------------------------------------------------------------------
delete_docker_container() {

  # Stops and removes docker container.
  # Args:
  #   arg1 - docker id to delete

  docker stop -t 5 "$id" || err || return
  docker rm "$id" || err
}

# vim helpers -----------------------------------------------------------------
#include globals.sh
# vim:ft=sh:sw=2:et:ts=2:
