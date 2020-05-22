# ---------------------------------------------------------------------------
err() {

  # In case of error print the function call stack
  # No args expected

  [[ $ERR_CALLED == "$TRUE" ]] && return $ERROR
  ERR_CALLED=$TRUE
  local frame=0
  printf '\n' >"$E"
  while caller $frame; do
    ((frame++))
  done | tac >"$E"
  printf '\n' >"$E"
  return $ERROR
}

# vim:ft=sh:sw=2:et:ts=2:
