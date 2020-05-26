# UT - Utilities

# _UT is an associative array that holds data specific to shared utilities.
declare -A _UT

# Declare externally defined global variables ---------------------------------

declare OK STDERR

# Getters/Setters -------------------------------------------------------------

# UT_runlogfile outputs the value of _UT[runlogfile], which contains the name of
# the file written to when running UT_run_with_progress.
UT_runlogfile() {
  printf '%s' "${_UT[runlogfile]}"
}

# Public Functions ------------------------------------------------------------

# UT_disable_colours resets variables used for colourised output so that they
# contain no colour terminal escapes. Useful if stdin is not a terminal.
UT_disable_colours() {
  _UT[yellow]=
  _UT[green]=
  _UT[red]=
  _UT[normal]=
  _UT[probablysuccess]="✓"
  _UT[success]="✓"
  _UT[failure]="✕"
}

# UT_run_with_progress displays a progress spinner, display item text, display
# a tick or cross based on the exit code.
# Args: arg1   - the text to display.
#       arg2-N - remaining args are the program to run and its arguments.
UT_run_with_progress() {

  local displaytext=$1 retval int spinner=()

  _UT[runlogfile]=$(mktemp -p /var/tmp) || {
    printf 'ERROR: mktmp failed.\n' >"${STDERR}"
    err || return
  }
  shift

  while read -r char; do
    spinner+=("${char}")
  done <<<"$(grep -o . <<<"${_UT[spinnerchars]}")"

  # Run the command in the background
  (
    eval "$*" &>"${_UT[runlogfile]}"
  ) &

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
    printf '\r  %s\n' "${_UT[probablysuccess]}"
  elif [[ ${retval} -eq 0 ]]; then
    printf '\r  %s\n' "${_UT[success]}"
  else
    printf '\r  %s\n' "${_UT[failure]}"
  fi

  # Restore the cursor
  tput cnorm

  return "${retval}"
}

# UT_cleanup removes artifacts that were created during execution.
UT_cleanup() {

  # Called when the script exits.

  local int

  # Kill the spinny, and anything else, if they're running
  [[ -n $(jobs -p) ]] && printf '%s\r  ✕%s\n' "${_UT[red]}" "${_UT[normal]}"
  for int in $(jobs -p); do kill "${int}"; done

  # If progress spinner crashed make sure the cursor is shown
  [ -t 1 ] && tput cnorm

  return "${OK}"
}

# Private Functions -----------------------------------------------------------

# _UT_new sets the initial values for the _UT associative array.
# This function is called by parse_options once it knows which component is
# being requested but before it sets any array members.
# Args: None expected.
_UT_new() {
  _UT[yellow]=$(tput setaf 3)
  _UT[green]=$(tput setaf 2)
  _UT[red]=$(tput setaf 1)
  _UT[normal]=$(tput sgr0)
  _UT[probablysuccess]="${_UT[yellow]}✓${_UT[normal]}"
  _UT[success]="${_UT[green]}✓${_UT[normal]}"
  _UT[failure]="${_UT[red]}✕${_UT[normal]}"
  _UT[runlogfile]=
  _UT[spinnerchars]='◐◓◑◒'
}

# Initialise _UT
_UT_new

# vim helpers -----------------------------------------------------------------
#include globals.sh
# vim:ft=sh:sw=2:et:ts=2:
