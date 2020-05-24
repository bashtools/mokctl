# UT - Utilities

# UT is an associative array that holds data specific to shared utilities.
declare -A UT

# Declare externally defined gloabl variables ---------------------------------

declare OK STDERR

# Getters/Setters -------------------------------------------------------------

UT_get_runfile() {
  printf '%s' "${UT[runfile]}"
}

UT_get_probablysuccess() {
  printf '%s' "${UT[success]}"
}

UT_get_success() {
  printf '%s' "${UT[success]}"
}

UT_get_failure() {
  printf '%s' "${UT[success]}"
}

# Public Functions ------------------------------------------------------------

# UT_new sets the initial values for the UT associative array.
# This function is called by parse_options once it knows which component is
# being requested but before it sets any array members.
# Args: None expected.
UT_new() {
  UT[yellow]=$(tput setaf 3)
  UT[green]=$(tput setaf 2)
  UT[red]=$(tput setaf 1)
  UT[normal]=$(tput sgr0)
  UT[probablysuccess]="${UT[yellow]}✓${UT[normal]}"
  UT[success]="${UT[green]}✓${UT[normal]}"
  UT[failure]="${UT[red]}✕${UT[normal]}"
  UT[runfile]=
  UT[spinnerchars]='◐◓◑◒'
}

# UT_disable_colours resets variables used for colourised output so that they
# contain no colour terminal escapes. Useful if stdin is not a terminal.
UT_disable_colours() {
  UT[yellow]=
  UT[green]=
  UT[red]=
  UT[normal]=
  UT[probablysuccess]="✓"
  UT[success]="✓"
  UT[failure]="✕"
}

# ---------------------------------------------------------------------------
UT_run_with_progress() {

  # Display a progress spinner, display item text, display a tick or cross
  # based on the exit code.
  # Args:
  #   arg1 - the text to display
  #   argN - remaining args are the program and its arguments

  local displaytext=$1 retval int spinner=()

  UT[runfile]=$(mktemp -p /var/tmp) || {
    printf 'ERROR: mktmp failed.\n' >"${STDERR}"
    err || return
  }
  shift

  while read -r char; do
    spinner+=("${char}")
  done <<<"$(grep -o . <<<"${UT[spinnerchars]}")"

  # Run the command in the background
  (
    eval "$*"
  ) &>"${UT[runfile]}" &

  # Turn the cursor off
  tput civis

  # Start the spin animation
  printf "%s" "${displaytext}"
  (while true; do
    for int in {0..3}; do
      printf '\r  %s ' "${spinner[int]}"
      sleep .1
    done
  done) &

  # Wait for the command to finish
  wait %1 2>/dev/null
  retval=$?

  # Kill the spinner
  kill %2 2>/dev/null

  # Mark success/fail
  if [[ ${retval} -eq 127 ]]; then
    # The job finished before we started waiting for it
    printf '\r  %s\n' "$(UT_get_probablysuccess)"
  elif [[ ${retval} -eq 0 ]]; then
    printf '\r  %s\n' "$(UT_get_success)"
  else
    printf '\r  %s\n' "$(UT_get_failure)"
  fi

  # Restore the cursor
  tput cnorm

  return "${retval}"
}

# ---------------------------------------------------------------------------
UT_cleanup() {

  # Called when the script exits.

  local int

  # If progress spinner crashed make sure the cursor is shown
  [ -t 1 ] && tput cnorm

  # Kill the spinny, and anything else, if they're running
  [[ -n $(jobs -p) ]] && printf '%s\r  ✕%s\n' "${UT[red]}" "${UT[normal]}"
  for int in $(jobs -p); do kill "${int}"; done

  return "${OK}"
}

# Private Functions -----------------------------------------------------------

# vim helpers -----------------------------------------------------------------
#include globals.sh
# vim:ft=sh:sw=2:et:ts=2:
