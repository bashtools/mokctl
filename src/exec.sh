# ---------------------------------------------------------------------------
exec_usage() {

  cat <<'EnD'
EXEC has no subcommands. Exec into a container.
 
exec options:
 
 Format:
  exec [NAME]
  NAME        - (optional) The name of the container to log into.
                If this option is empty then the user will be offered
                a choice of containers to log in to. If there is only
                one cluster and one node then NAME can be left empty
                and it will log into the only available container.

EnD
}

# ---------------------------------------------------------------------------
do_exec() {

  do_exec_sanity_checks || return
  do_exec_nomutate "$EXEC_CONTAINER_NAME"
}

# ---------------------------------------------------------------------------
do_exec_sanity_checks() {

  # No sanity checks required.
  # Globals: None
  # No args expected

  :
}

# ---------------------------------------------------------------------------
do_exec_nomutate() {

  # Execs into the container referenced by arg1. If just 'mokctl exec' is
  # called without options then the user is offered a selection of existing
  # clusters to exec into.
  #
  # Args
  #  arg1 - Full name of container

  local names int ans lines containernames

  GET_CLUSTER_SHOW_HEADER=$FALSE
  names=$(do_get_clusters_nomutate) || return
  names=$(printf '%s' "$names" | awk '{ print $3; }')
  readarray -t containernames <<<"$names"

  if [[ -n $1 ]]; then

    # The caller gave a specific name for exec.
    # Check if the container name exists

    if grep -qs "^$1$" <<<"$names"; then
      run_docker_exec "$1" || return
      return $OK
    else
      printf 'ERROR: Cannot exec into non-existent container: "%s".\n' \
        "$1"
      return $ERROR
    fi

  elif [[ ${#containernames[*]} == 1 ]]; then

    # If there's only one container just log into it without asking
    run_docker_exec "${containernames[0]}"

  else

    # The caller supplied no container name.
    # Present some choices

    printf 'Choose the container to log in to:\n\n'

    GET_CLUSTER_SHOW_HEADER=$TRUE
    readarray -t lines <<<"$(do_get_clusters_nomutate)" || return

    # Print the header then print the items in the loop
    printf '   %s\n' "${lines[0]}"
    for int in $(seq 1 $((${#lines[*]} - 1))); do
      printf '%00d) %s\n' "$int" "${lines[int]}"
    done | sort -k 4

    printf "\nChoose a number (Enter to cancel)> "
    read -r ans

    [[ -z $ans || $ans -lt 0 || $ans -gt $((${#lines[*]} - 1)) ]] && {
      printf '\nInvalid choice. Aborting.\n'
      return $OK
    }

    run_docker_exec "${containernames[ans - 1]}"
  fi
}

# ---------------------------------------------------------------------------
run_docker_exec() {

  # Exec into the docker container
  # Args:
  #   arg1 - docker container name
  #   arg2 - command to run

  local cmd=${2:-bash}

  read -rt 0.1
  if [[ $CONTAINERRT == "podman" ]]; then
    exec podman exec -ti "$1" "$cmd"
  elif [[ $CONTAINERRT == "podman" ]]; then
    exec docker exec -ti "$1" "$cmd"
  fi
}

# vim helpers -----------------------------------------------------------------
#include globals.sh
# vim:ft=sh:sw=2:et:ts=2:
