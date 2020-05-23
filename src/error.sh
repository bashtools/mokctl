# ER - Error handling

# ER is an associative array that holds data specific to error handling.
declare -A ER

# Declare externally defined associative arrays -------------------------------

# Defined in GL (globals.sh)
declare OK ERROR STOP STDERR

# Getters/Setters -------------------------------------------------------------

# Public Functions ------------------------------------------------------------

# ER_init sets the initial values for the ER associative array.
# Args: None expected.
BI_init() {

  ER[errcalled]=

}

ER_err() {
  return "$(_ER_err)"
}

# Private Functions -----------------------------------------------------------

# ---------------------------------------------------------------------------
_ER_err() {

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

fakefunc() {
}

# vim helpers -----------------------------------------------------------------
#include globals.sh
# vim:ft=sh:sw=2:et:ts=2:
