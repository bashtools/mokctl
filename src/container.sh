# CU - Container Utils

# CU is an associative array that holds data specific to containers.
declare -A CU

# Declare externally defined variables ----------------------------------------

declare OK ERROR STDERR

# Getters/Setters -------------------------------------------------------------

# CU_get_imgprefix gets the prefix to be used with docker build. For podman
# it is 'localhost/'. For docker it is empty.
CU_get_imgprefix() {
  printf '%s' "${CU[imgprefix]}"
}

# Public Functions ------------------------------------------------------------

# CU_init sets the initial values for the CU associative array and works
# out which container runtime to use, podman or docker.
# This function is called by main().
# Args: None expected.
CU_init() {

  CU[imgprefix]=
  CU[containerrt]=
  CU[label]='MokCluster'

  _CU_podman_or_docker || return
}

CU_cleanup() {
  :
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

  docker ps -a -f label="${CU[label]}${1}" -q || {
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
