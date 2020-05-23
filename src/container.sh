# CT - Container Utils

# The following lines allow the use of '[Ctrl-i' and '[I' (do ':help [I').
#include getcluster.sh
#include createcluster.sh
#include util.sh
#include main.sh

# CT is an associative array that holds data specific to containers.
declare -A CT

# Declare externally defined associative arrays -------------------------------

declare -A UT
declare -A ERR

# Getters/Setters -------------------------------------------------------------

# CT_get_imgprefix gets the prefix to be used with docker build. For podman
# it is 'localhost/'. For docker it is empty.
CT_get_imgprefix() {
  printf '%s' "${CT[imgprefix]}"
}

# Public Functions ------------------------------------------------------------

# CT_init sets the initial values for the CT associative array.
# This function is called by main().
# Args: None expected.
CT_init() {

  CT[imgprefix]=
  CT[containerrt]=
  CT[label]='MokCluster'

  _CT_podman_or_docker || return
}

# Private Functions -----------------------------------------------------------

# CT_podman_or_docker checks to see if docker and/or podman are installed
# and sets the imgprefix array member accordingly, and also defines the
# function to be used. Podman is preferred if both are installed.
# This function is called by main().
CT_podman_or_docker() {

  local id

  if type podman &>/dev/null; then
    CT[imgprefix]="localhost/"
    CT[containerrt]="podman"
    local id
    id=$(id -u)
    [[ ${id} -ne 0 ]] && {
      cat <<'EnD' >"${ERR[stderr]}"
Must run 'podman' as root! Try using:

  $ alias mokctl="sudo mokctl"

Then run the command again.
EnD
      return "${ERR[error]}"
    }
    docker() {
      podman "$@"
    }
  elif type docker &>/dev/null; then
    CT[imgprefix]=""
    CT[containerrt]="docker"
    docker() {
      docker "$@"
    }
  else
    printf 'ERROR: Neither "podman" nor "docker" were found.\n' >"${ERR[E]}"
    printf 'Please install one of "podman" or "docker".\nAborting.\n' >"${ERR[E]}"
    return "${UT[ERROR]}"
  fi

  return "${UT[OK]}"
}

# ---------------------------------------------------------------------------
get_docker_container_ip() {

  # Args:
  #   arg1 - docker container id or container name

  docker inspect \
    --format='{{.NetworkSettings.IPAddress}}' \
    "$1" || {
    printf 'ERROR: docker failed\n\n' >"${E}"
    err || return
  }

}

# ---------------------------------------------------------------------------
get_mok_cluster_docker_ids() {

  # Use 'docker ps .. label= ..' to get a list of mok clusters
  # Args
  #   arg1 - mok cluster name, optional

  docker ps -a -f label="${CT[label]}${1}" -q || {
    printf 'ERROR: docker failed\n' >"${E}"
    err || return
  }
}

# ---------------------------------------------------------------------------
get_info_about_container_using_docker() {

  # Use 'docker inspect $id' to get details about container $id
  # Args
  #   arg1 - docker container id

  docker inspect "$1" || {
    printf 'ERROR: docker failed\n' >"${E}"
    err || return
  }
}

# vim helpers -----------------------------------------------------------------

# The following lines allow the use of '[C-i' and '[I' (do ':help [I') in vim.
#include buildimage.sh
#include createcluster.sh
#include deletecluster.sh
#include embed-dockerfile.sh
#include error.sh
#include exec.sh
#include getcluster.sh
#include main.sh
#include util.sh

# vim:ft=sh:sw=2:et:ts=2:
