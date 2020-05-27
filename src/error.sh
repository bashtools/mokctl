# ER - Error handling

# ER is an associative array that holds data specific to error handling.
declare -A ER

# Declare externally defined associative arrays -------------------------------

# Defined in GL (globals.sh)
declare ERROR TRUE STDERR

# Public Functions ------------------------------------------------------------

# ER_err outputs a stacktrace and returns ERROR status.
# Args: None expected.
ER_err() {

  # In case of error print the function call stack
  # No args expected

  [[ ${ER[errcalled]} == "${TRUE}" ]] && return "${ERROR}"
  ER[errcalled]="${TRUE}"
  local frame=0
  printf '\n' >"${STDERR}"
  while caller "${frame}"; do
    ((frame++))
  done | tac >"${STDERR}"
  printf '\n' >"${STDERR}"
  return "${ERROR}"
}

# err is a synonym for ER_err to aid with code readability.
err() {
  ER_err
  return
}

# Private Functions -----------------------------------------------------------

# ER_new sets the initial values for the ER associative array.
# Args: None expected.
_ER_new() {
  ER[errcalled]=
}

# Initialise ER
_ER_new || exit 1

# vim helpers -----------------------------------------------------------------
#include globals.sh
# vim:ft=sh:sw=2:et:ts=2:
