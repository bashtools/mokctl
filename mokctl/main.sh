# ---------------------------------------------------------------------------
main() {

  # Execution begins here

  local r=$OK

  trap cleanup EXIT

  set_globals || return

  podman_or_docker || return

  sanity_checks || return

  parse_options "$@" || r=$?

  if [[ $r -eq $ERROR ]]; then
    return $ERROR
  elif [[ $r -eq $STOP ]]; then
    return $OK
  fi

  case "$COMMAND" in
  create) do_create ;;
  delete) do_delete ;;
  build) do_build ;;
  get) do_get ;;
  exec) do_exec ;;
  esac
}

# do_create chooses which function to run for 'create SUBCOMMAND'.
# Args: None expected.
do_create() {

  # Calls the correct command/subcommand function

  case ${PA[SUBCOMMAND]} in
  cluster)
    CC_sanity_checks || return
    CC_cluster_create
    ;;
  esac
}

# do_build starts the build image process.
# Calls the correct build command/subcommand function
# Args: None expected.
do_build() {

  case ${PA[SUBCOMMAND]} in
  image)
    BI_sanity_checks || return
    BI_build_image
    ;;
  esac
}

# ---------------------------------------------------------------------------
sanity_checks() {

  # Check our environment
  # No args expected

  local binary

  for binary in tac column tput grep sed; do
    if ! command -v "$binary" >&/dev/null; then
      printf 'ERROR: "%s" binary not found in path. Aborting.' "$binary" >"$E"
      return 1
    fi
  done

  # Disable terminal escapes (colours) if stdout is not a terminal
  [ -t 1 ] || {
    colgreen=
    colred=
    colyellow=
    colreset=
    success="✓"
    probablysuccess="$success"
    failure="✕"
  }
}

# Calls main() if we're called from the command line
if [ "$0" = "${BASH_SOURCE[0]}" ] || [ -z "${BASH_SOURCE[0]}" ]; then
  main "$@"
fi

# vim:ft=sh:sw=2:et:ts=2:
