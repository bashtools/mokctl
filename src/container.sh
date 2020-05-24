# CU - Container Utilities

# CU is an associative array that holds data specific to containers.
declare -A CU

# Declare externally defined variables ----------------------------------------

declare OK ERROR STDERR

# Getters/Setters -------------------------------------------------------------

# CU_imgprefix gets the prefix to be used with docker build. For podman
# it is 'localhost/'. For docker it is empty.
CU_imgprefix() {
  printf '%s' "${CU[imgprefix]}"
}

# CU_labelkey gets the key value of the label that is applied to all
# cluster members for podman or docker.
CU_labelkey() {
  printf '%s' "${CU[labelkey]}"
}

# Public Functions ------------------------------------------------------------

# CU_init sets the initial values for the CU associative array and works
# out which container runtime to use, podman or docker.
# This function is called by main().
# Args: None expected.
CU_init() {

  CU[imgprefix]=
  CU[containerrt]=
  CU[labelkey]='MokCluster'

  _CU_podman_or_docker || return
}

CU_cleanup() {
  :
}

# CU_get_cluster_docker_ids outputs just the container IDs, one per line
# for any MOK cluster, unless arg1 is set, in which case just the IDs
# for the requests cluster name are output.
# Args: arg1 - The cluster name, optional.
CU_get_cluster_docker_ids() {

  local value output

  [[ -n $1 ]] && value="=$1"

  output=$(docker ps -a -f label="${CU[label]}${value}" -q) || {
    printf 'ERROR: Docker command failed\n\n' >"${STDERR}"
    err || return
  }

  output=$(printf '%s' "${output}" | sed 's/$//')

  printf '%s' "${output}"

  return "${OK}"
}

# CU_get_cluster_size searches for an existing cluster using labels and outputs
# the number of containers in that cluster. All cluster nodes are labelled with
# LABELKEY="${CC[clustername]}"
# Args: arg1 - The cluster name to search for.
CU_get_cluster_size() {

  local output
  declare -a nodes

  [[ -z ${1} ]] && {
    printf 'INTERNAL ERROR: Cluster name cannot be empty.' >"${STDERR}"
    err || return
  }

  output=$(get_docker_ids_for_cluster "$1") || return

  # readarray will read null as an array item so don't run
  # through readarray if it's null
  [[ -z ${output} ]] && {
    printf '0'
    return "${OK}"
  }

  # read the nodes array and delete blank lines
  readarray -t nodes <<<"${output}"

  printf '%d' "${#nodes[*]}"
}

# CU_create_container creates and runs a container with settings suitable for
# running privileged containers that can manipulate cgroups.
# Args: arg1 - The string used to set the name and hostname.
#       arg2 - The label to assign to the container.
#       arg3 - The k8s base image version to use.
CU_create_container() {

  local imagename img what allimgs

  [[ -z $1 || -z $2 || -z $3 ]] && {
    printf 'INTERNAL ERROR: Neither arg1, arg2 nor arg3 can be empty.'
    err || return
  }

  img=$(BI_baseimagename) || err || return

  local imglocal="${CU[imgprefix]}local/${img}-v${3}"
  local imgremote="docker.io/mclarkson/${img}-v${3}"

  # Prefer a locally built container over one downloaded from a registry
  allimgs=$(podman images -n) || {
    what="${CU[containerrt]}"
    printf 'ERROR: %s returned an error' "${what}"
    err || return
  }

  if echo "${allimgs}" | grep -qs "${imglocal}"; then
    imagename="${imglocal}"
  elif echo "${allimgs}" | grep -qs "${imgremote}"; then
    imagename="${imgremote}"
  else
    cat <<EnD
ERROR: No container base image found. Use either:

  $ mokctl build image
OR
  $ mokctl build image --get-prebuilt-image

Then try running 'mokctl create ...' again.
EnD
    return "${ERROR}"
  fi

  docker run --privileged \
    -v /sys/fs/cgroup:/sys/fs/cgroup:ro \
    -v /lib/modules:/lib/modules:ro \
    --tmpfs /run --tmpfs /tmp \
    --detach \
    --name "$1" \
    --hostname "$1" \
    --label "$2" \
    "${imagename}" || err
}

# Private Functions -----------------------------------------------------------

# CU_podman_or_docker checks to see if docker and/or podman are installed
# and sets the imgprefix array member accordingly, and also defines the
# function to be used. Podman is preferred if both are installed.
# This function is called by main().
# Args: No args expected.
_CU_podman_or_docker() {

  local id

  if type podman &>/dev/null; then
    CU[imgprefix]="localhost/"
    CU[containerrt]="podman"
    local id
    id=$(id -u)
    [[ ${id} -ne 0 ]] && {
      cat <<'EnD' >"${STDERR}"
Must run 'podman' as root! Try using:

  $ alias mokctl="sudo mokctl"

Then run the command again.
EnD
      return "${ERROR}"
    }
    docker() {
      podman "$@"
    }
  elif type docker &>/dev/null; then
    CU[imgprefix]=""
    CU[containerrt]="docker"
    docker() {
      docker "$@"
    }
  else
    printf 'ERROR: Neither "podman" nor "docker" were found.\n' \
      >"${STDERR}"
    printf 'Please install one of "podman" or "docker".\nAborting.\n' \
      >"${STDERR}"
    return "${ERROR}"
  fi

  return "${OK}"
}

# ---------------------------------------------------------------------------
get_docker_container_ip() {

  # Args:
  #   arg1 - docker container id or container name

  docker inspect \
    --format='{{.NetworkSettings.IPAddress}}' \
    "$1" || {
    printf 'ERROR: docker failed\n\n' >"${STDERR}"
    err || return
  }

}

# ---------------------------------------------------------------------------
get_mok_cluster_docker_ids() {

  # Use 'docker ps .. label= ..' to get a list of mok clusters
  # Args
  #   arg1 - mok cluster name, optional

  docker ps -a -f label="${CU[labelkey]}${1}" -q || {
    printf 'ERROR: docker failed\n' >"${STDERR}"
    err || return
  }
}

# ---------------------------------------------------------------------------
get_info_about_container_using_docker() {

  # Use 'docker inspect $id' to get details about container $id
  # Args
  #   arg1 - docker container id

  docker inspect "$1" || {
    printf 'ERROR: docker failed\n' >"${STDERR}"
    err || return
  }
}

# vim helpers -----------------------------------------------------------------
#include globals.sh
# vim:ft=sh:sw=2:et:ts=2:
