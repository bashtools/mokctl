# GLOBALS
# Don't change any globals

# Constants
readonly LABELKEY="MokCluster"
readonly BASEIMAGENAME="mok-centos-7"
readonly OK=0
readonly ERROR=1
readonly FALSE=0
readonly TRUE=1
readonly STOP=2
readonly SPINNER=('◐' '◓' '◑' '◒')

colyellow=$(tput setaf 3)
colgreen=$(tput setaf 2)
colred=$(tput setaf 1)
colreset=$(tput sgr0)
probablysuccess="$colyellow✓$colreset"
success="$colgreen✓$colreset"
failure="$colred✕$colreset"

# The initial state of the parser
STATE="COMMAND"

# Parser sets these:
COMMAND=
SUBCOMMAND=
CREATE_CLUSTER_NAME=
BUILD_IMAGE_K8SVER=
CREATE_CLUSTER_K8SVER=
CREATE_CLUSTER_WITH_LB=
CREATE_CLUSTER_SKIPLBSETUP=
CREATE_CLUSTER_NUM_MASTERS=
CREATE_CLUSTER_NUM_WORKERS=
CREATE_CLUSTER_SKIPMASTERSETUP=
CREATE_CLUSTER_SKIPWORKERSETUP=
DELETE_CLUSTER_NAME=
GET_CLUSTER_NAME=
GET_CLUSTER_SHOW_HEADER=
EXEC_CONTAINER_NAME=

# For outputting errors
E="/dev/stderr"
ERR_CALLED=

PODMANIMGPREFIX=
BUILD_GET_PREBUILT=
CONTAINERRT=

# Directory to unpack the build files
DOCKERBUILDTMPDIR=

# For the spinning progress animation
RUNWITHPROGRESS_OUTPUT=

# END GLOBALS

# ===========================================================================
# MOKCTL DELETE CLUSTER
# ===========================================================================

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
    run_with_progress \
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

# vim:ft=sh:sw=2:et:ts=2:
