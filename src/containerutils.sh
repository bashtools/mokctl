# shellcheck shell=bash disable=SC2148
# CU - Container Utilities

# _CU is an associative array that holds data specific to containers.
declare -A _CU

# Declare externally defined variables ----------------------------------------

declare OK ERROR STDERR

# Getters/Setters -------------------------------------------------------------

# CU_containerrt getter outputs the container runtime (podman or docker)
# that has been chosen.
CU_containerrt() {
  printf '%s' "${_CU[containerrt]}"
}

# CU_imgprefix getter outputs the prefix to be used with docker build. For
# podman it is 'localhost/'. For docker it is empty.
CU_imgprefix() {
  printf '%s' "${_CU[imgprefix]}"
}

# CU_labelkey getter outputs the key value of the label that is applied to all
# cluster member's container labels for podman or docker.
CU_labelkey() {
  printf '%s' "${_CU[labelkey]}"
}

# Public Functions ------------------------------------------------------------

# CU_cleanup removes artifacts that were created during execution. Currently
# this does nothing and this function could be deleted.
CU_cleanup() { :; }

# CU_get_cluster_container_ids outputs just the container IDs, one per line
# for any MOK cluster, unless arg1 is set, in which case just the IDs
# for the requested cluster name are output.
# Args: arg1 - The cluster name, optional.
CU_get_cluster_container_ids() {

  local value output

  [[ -n $1 ]] && value="=$1"

  output=$(docker ps -a -f label="${_CU[labelkey]}${value}" -q) || {
    printf 'ERROR: %s command failed\n' "${_CU[containerrt]}" >"${STDERR}"
    err || return
  }

  output=$(printf '%s' "${output}" | sed 's/$//')

  printf '%s' "${output}"

  return "${OK}"
}

# CU_get_cluster_size searches for an existing cluster using labels and outputs
# the number of containers in that cluster. All cluster nodes are labelled with
# "${_CU[labelkey]}=${CC[clustername]}"
# Args: arg1 - The cluster name to search for.
CU_get_cluster_size() {

  local output
  declare -a nodes

  [[ -z ${1} ]] && {
    printf 'INTERNAL ERROR: Cluster name cannot be empty.\n' >"${STDERR}"
    err || return
  }

  output=$(CU_get_cluster_container_ids "$1") || err || return

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

# CU_get_container_ip outputs the IP address of the container.
# Args: arg1 - docker container id or container name to query.
CU_get_container_ip() {

  [[ -z ${1} ]] && {
    printf 'INTERNAL ERROR: Container ID (arg1) cannot be empty.\n' >"${STDERR}"
    err || return
  }

  docker inspect \
    --format='{{.NetworkSettings.Networks.mok_network.IPAddress}}' \
    "$1" || {
    printf 'ERROR: %s inspect failed\n' "${_CU[containerrt]}" >"${STDERR}"
    err || return
  }
}

# CU_get_container_info uses 'docker/podman inspect $id' to output
# container details.
# Args: arg1 - docker container id
CU_get_container_info() {

  [[ -z ${1} ]] && {
    printf 'INTERNAL ERROR: Container ID (arg1) cannot be empty.\n' >"${STDERR}"
    err || return
  }

  docker inspect "$1" || {
    printf 'ERROR: %s inspect failed\n' "${_CU[containerrt]}" >"${STDERR}"
    err || return
  }
}

# CU_create_container creates and runs a container with settings suitable for
# running privileged containers that can manipulate cgroups.
# Args: arg1 - The string used to set the name and hostname.
#       arg2 - The label to assign to the container.
#       arg3 - The k8s base image version to use.
CU_create_container() {

  local imagename img allimgs

  [[ -z $1 || -z $2 || -z $3 ]] && {
    printf 'INTERNAL ERROR: Neither arg1, arg2 nor arg3 can be empty.\n' \
      >"${STDERR}"
    err || return
  }

  img=$(BI_baseimagename) || err || return

  local imglocal="${_CU[imgprefix]}local/${img}-v${3}"
  local imgremote="myownkind/${img}-v${3}"

  # Prefer a locally built container over one downloaded from a registry
  allimgs=$(docker images | tail -n +2) || {
    printf 'ERROR: %s returned an error\n' "${_CU[containerrt]}" >"${STDERR}"
    err || return
  }

  if echo "${allimgs}" | grep -qs "${imglocal}"; then
    imagename="${imglocal}"
  elif echo "${allimgs}" | grep -qs "${imgremote}"; then
    imagename="${imgremote}"
  else
    cat <<EnD
ERROR: No container base image found. Use either:

  $ mok build image
OR
  $ mok build image --get-prebuilt-image

Then try running 'mok create ...' again.
EnD
    return "${ERROR}"
  fi

  docker network exists mok_network || {
    docker network create mok_network || {
      printf 'ERROR: docker network create failed\n' >"${STDERR}"
      err || return
    }
  }

  docker run --privileged \
    --network mok_network \
    -v /lib/modules:/lib/modules:ro \
    --systemd=always \
    --detach \
    --name "$1" \
    --hostname "$1" \
    --label "$2" \
    "${imagename}" \
    /usr/local/bin/entrypoint /lib/systemd/systemd log-level=info unit=sysinit.target || {
    printf 'ERROR: %s run failed\n' "${_CU[containerrt]}" >"${STDERR}"
    err || return
  }
}

# Private Functions -----------------------------------------------------------

# _CU_new sets the initial values for the Container Utils associative array.
# Args: None expected.
_CU_new() {
  _CU[imgprefix]=
  _CU[labelkey]="MokCluster"
  _CU[containerrt]=

  _CU_podman_or_docker
}

# CU_podman_or_docker checks to see if docker and/or podman are installed and
# sets the imgprefix and containerrt array members accordingly. It also defines
# the docker function to run the detected container runtime. Docker is
# preferred if both are installed.
# Args: No args expected.
_CU_podman_or_docker() {

  local id

  if type podman &>/dev/null; then
    _CU[imgprefix]="localhost/"
    _CU[containerrt]="podman"
    local id
    id=$(id -u)
    [[ ${id} -ne 0 ]] && {
      cat <<EnD >"${STDERR}"
Please use 'sudo' to run this command.

  $ sudo mok $(MA_program_args)

Try using:

  $ alias mok="sudo mok"

Then run the command again.
EnD
      return "${ERROR}"
    }
    docker() {
      podman "$@"
    }
  elif type docker &>/dev/null; then
    _CU[imgprefix]=""
    _CU[containerrt]="docker"
    if docker ps >/dev/stdout 2>&1 | grep -qs 'docker.sock.*permission denied'; then
      cat <<'EnD' >"${STDERR}"
Not enough permissions to write to 'docker.sock'.
Fix the permissions for this user or run as root, such as:

  $ alias mok="sudo mok"

Then run the command again.
EnD
      return "${ERROR}"
    fi
  else
    printf 'ERROR: Neither "podman" nor "docker" were found.\n' \
      >"${STDERR}"
    printf 'Please install one of "podman" or "docker".\nAborting.\n' \
      >"${STDERR}"
    return "${ERROR}"
  fi

  return "${OK}"
}

# Initialise _CU
_CU_new || exit 1

# vim helpers -----------------------------------------------------------------
#include globals.sh
# vim:ft=sh:sw=2:et:ts=2:
