# CT - Container Utils

# The following lines allow the use of '[Ctrl-i' and '[I' (do ':help [I').
#include util.sh
#include main.sh

# CT is an associative array that holds data specific to containers.
declare -A CT

# ---------------------------------------------------------------------------
podman_or_docker() {

  # Prefer podman over docker. Docker is getting hard to install on Fedora.

  if type podman &>/dev/null; then
    PODMANIMGPREFIX="localhost/"
    CONTAINERRT="podman"
    local id
    id=$(id -u)
    [[ $id -ne 0 ]] && {
      cat <<'EnD' >/dev/stderr
Must run 'podman' as root! Try using:

  $ alias mokctl="sudo mokctl"

Then run the command again.
EnD
      return $ERROR
    }
    docker() {
      podman "$@"
    }
  elif type docker &>/dev/null; then
    CONTAINERRT="podman"
    docker() {
      docker "$@"
    }
  else
    printf 'ERROR: Neither "podman" nor "docker" were found.\n'
    printf 'Please install one of "podman" or "docker".\nAborting.\n'
    return $ERROR
  fi

  return $OK
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
