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
# MOKCTL GET CLUSTER
# ===========================================================================

# ---------------------------------------------------------------------------
get_usage() {

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

  [[ -n $clustname ]] && clustname="=$clustname"

  ids=$(get_mok_cluster_docker_ids "$clustname") || return

  if [[ -z $ids ]]; then
    return $OK
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

    info=$(get_info_about_container_using_docker "$id") || return

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
get_docker_container_ip() {

  # Args:
  #   arg1 - docker container id or container name

  docker inspect \
    --format='{{.NetworkSettings.IPAddress}}' \
    "$1" || {
    printf 'ERROR: docker failed\n\n' >"$E"
    err || return
  }

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

# ---------------------------------------------------------------------------
get_info_about_container_using_docker() {

  # Use 'docker inspect $id' to get details about container $id
  # Args
  #   arg1 - docker container id

  docker inspect "$1" || {
    printf 'ERROR: docker failed\n' >"$E"
    err || return
  }
}

# vim:ft=sh:sw=2:et:ts=2:
