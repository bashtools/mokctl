# UT - Utilities

# _UT is an associative array that holds data specific to shared utilities.
declare -A _UT

# Declare externally defined global variables ---------------------------------

declare OK STDERR FALSE TRUE

# Getters/Setters -------------------------------------------------------------

# UT_runlogfile getter outputs the value of _UT[runlogfile], which contains the
# name of the file written to when running UT_run_with_progress.
UT_runlogfile() {
  printf '%s' "${_UT[runlogfile]}"
}

# UT_tailf getter indicates whether a log will be shown in real-time during the
# 'run', TRUE, or not, FALSE.
# Args
UT_tailf() {
  printf '%s' "${_UT[tailf]}"
}

# UT_tailf setter indicates whether a log should be shown during the 'run',
# TRUE, or not, FALSE.
# Args: arg1 - Whether to tail, TRUE or FALSE.
UT_set_tailf() {
  _UT[tailf]="$1"
}

# UT_set_plain setter sets plain output, with no colour, animations, or UTF
# high byte characters.
# Args: arg1 - Whether to show plain output, TRUE or FALSE.
UT_set_plain() {
  _UT[plain]="$1"
  UT_disable_colours
}

# Public Functions ------------------------------------------------------------

# UT_disable_colours resets variables used for colourised output so that they
# contain no colour terminal escapes. Useful if stdin is not a terminal.
UT_disable_colours() {
  _UT[yellow]=
  _UT[green]=
  _UT[red]=
  _UT[normal]=
  _UT[probablysuccess]="PROBABLY SUCCESS (!)"
  _UT[success]="SUCCESS"
  _UT[failure]="FAIL"
}

# UT_run_with_progress displays a progress spinner, item text, and a tick or
# cross based on the exit code.
# Args: arg1   - the text to display.
#       arg2-N - remaining args are the program to run and its arguments.
UT_run_with_progress() {

  local displaytext=$1 retval int spinner=()

  _UT[runlogfile]=$(mktemp -p /var/tmp) || {
    printf 'ERROR: mktmp failed.\n' >"${STDERR}"
    err || return
  }
  shift

  if [[ ${_UT[tailf]} == "${FALSE}" && ${_UT[plain]} == "${TRUE}" ]]; then

    printf '%s' "${displaytext}"

    eval "$*" &>"${_UT[runlogfile]}"
    retval=$?

    # Mark success/fail
    if [[ ${retval} -eq 0 ]]; then
      printf ' .. %s\n' "${_UT[success]}"
    else
      printf ' .. %s\n' "${_UT[failure]}"
    fi

  elif [[ ${_UT[tailf]} == "${FALSE}" ]]; then

    while read -r char; do
      spinner+=("${char}")
    done <<<"$(grep -o . <<<"${_UT[spinnerchars]}")"

    (
      eval "$*" &>"${_UT[runlogfile]}"
    ) &

    # Turn the cursor off
    tput civis

    # Start the spin animation
    printf ' %s' "${displaytext}"
    (while true; do
      for int in {0..3}; do
        printf '\r  %s ' "${spinner[int]}"
        sleep .1
      done
    done) &
    _UT[spinnerpid]=$!
    disown

    # Wait for the command to finish
    wait %1 2>/dev/null
    retval=$?

    # Kill the spinner
    kill "${_UT[spinnerpid]}" 2>/dev/null
    _UT[spinnerpid]=

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

  else

    (
      eval "$*" &>/dev/stdout
    ) &
    sleep 1

    # Wait for the command to finish
    wait %1 2>/dev/null
    retval=$?

    # Mark success/fail
    if [[ ${retval} -eq 127 ]]; then
      # The job finished before we started waiting for it
      printf '\n\nSTATUS: OK - (Probably)\n\n'
    elif [[ ${retval} -eq 0 ]]; then
      printf '\n\nSTATUS: OK\n\n'
    else
      printf '\n\nSTATUS: FAIL\n\n'
    fi
  fi

  return "${retval}"
}

# UT_cleanup removes any artifacts that were created during execution.
# This is called by 'MA_cleanup' trap only.
UT_cleanup() {

  # Called when the script exits.

  local int

  # Kill the spinny, and anything else, if they're running
  if [[ ${_UT[tailf]} == "${FALSE}" ]]; then
    [[ -n ${_UT[spinnerpid]} ]] && {
      printf '%s\r  ✕%s\n' "${_UT[red]}" "${_UT[normal]}"
      kill "${_UT[spinnerpid]}"
    }
    # If progress spinner crashed make sure the cursor is shown
    [ -t 1 ] && tput cnorm
  else
    kill "${_UT[spinnerpid]}"
  fi

  return "${OK}"
}

# Private Functions -----------------------------------------------------------

# _UT_new sets the initial values for the _UT associative array.
# Args: None expected.
_UT_new() {
  _UT[tailf]="${FALSE}"
  _UT[yellow]=$(tput setaf 3)
  _UT[green]=$(tput setaf 2)
  _UT[red]=$(tput setaf 1)
  _UT[normal]=$(tput sgr0)
  _UT[probablysuccess]="${_UT[yellow]}✓${_UT[normal]}"
  _UT[success]="${_UT[green]}✓${_UT[normal]}"
  _UT[failure]="${_UT[red]}✕${_UT[normal]}"
  _UT[runlogfile]=
  _UT[spinnerchars]='◐◓◑◒'
  _UT[spinnerpid]=
}

# Initialise _UT
_UT_new || exit 1

# vim helpers -----------------------------------------------------------------
#include globals.sh
# vim:ft=sh:sw=2:et:ts=2:
