UT_init() {
  colyellow=$(tput setaf 3)
  colgreen=$(tput setaf 2)
  colred=$(tput setaf 1)
  colreset=$(tput sgr0)
  probablysuccess="${colyellow}✓${colreset}"
  success="${colgreen}✓${colreset}"
  failure="${colred}✕${colreset}"

  declare -i OK=0
  declare -i ERROR=1
  #declare -i FALSE=0
  declare -i TRUE=1
  #declare -i STOP=2
  E=
}

# ---------------------------------------------------------------------------
err() {

  # In case of error print the function call stack
  # No args expected

  [[ ${ERR_CALLED} == "${TRUE}" ]] && return "${ERROR}"
  ERR_CALLED=${TRUE}
  local frame=0
  printf '\n' >"${E}"
  while caller "${frame}"; do
    ((frame++))
  done | tac >"${E}"
  printf '\n' >"${E}"
  return ${ERROR}
}

# ---------------------------------------------------------------------------
run_with_progress() {

  # Display a progress spinner, display item text, display a tick or cross
  # based on the exit code.
  # Args:
  #   arg1 - the text to display
  #   argN - remaining args are the program and its arguments

  local displaytext=$1 retval int

  RUNWITHPROGRESS_OUTPUT=$(mktemp -p /var/tmp) || {
    printf 'ERROR: mktmp failed.\n' >"$E"
    err || return
  }
  shift

  # Run the command in the background
  (
    sleep 1
    eval "$*"
  ) &>"$RUNWITHPROGRESS_OUTPUT" &

  # Turn the cursor off
  tput civis

  # Start the spin animation
  printf "%s" "$displaytext"
  (while true; do
    for int in {0..3}; do
      printf '\r  %s ' "${SPINNER[int]}"
      sleep .1
    done
  done) &

  # Wait for the command to finish
  wait %1 2>/dev/null
  retval=$?

  # Kill the spinner
  kill %2 2>/dev/null

  # Mark success/fail
  if [[ $retval -eq 127 ]]; then
    # The job finished before we started waiting for it
    printf '\r  %s\n' "$probablysuccess"
  elif [[ $retval -eq 0 ]]; then
    printf '\r  %s\n' "$success"
  else
    printf '\r  %s\n' "$failure"
  fi

  # Restore the cursor
  tput cnorm

  return $retval
}

# ---------------------------------------------------------------------------
cleanup() {

  # Called when the script exits.

  local int

  BI_cleanup

  # If progress spinner crashed make sure the cursor is shown
  [ -t 1 ] && tput cnorm

  # Kill the spinny, and anything else, if they're running
  [[ -n $(jobs -p) ]] && printf '%s\r  ✕%s\n' "$colred" "$colreset"
  for int in $(jobs -p); do kill "$int"; done

  return $OK
}

# vim:ft=sh:sw=2:et:ts=2:
