#!/usr/bin/env bash

declare -r TRUE=1 ERROR=1 STDERR="/dev/stderr"

err() {

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

classify_status() {
  cd e2e/crm114/ || err || exit 1
  crm classify.crm <../../hardcopy | sed -n '2p' | grep -Eo '(GOOD|BAD)'
}

classify_probability() {
  cd e2e/crm114/ || err || exit 1
  crm classify.crm <../../hardcopy | sed -n '2p' | sed -r 's/^.*prob: ([^ ]+).*/\1/'
}

save_hardcopy() {
  local date testnum status probability

  date=$(date +%Y-%m-%d-%s)
  testnum="$1"
  status="$2"
  probability="$3"

  mkdir -p e2e-logs
  cat -s hardcopy >"e2e-logs/${date}_test-${testnum}_${status}_${probability}.log"
}

main() {
  export PATH="../cmdline-player/:${PATH}"

  local status probability

  for x in 1 2; do
    cmdline-player -n "e2e/e2e-test-${x}.scr"
    while true; do
      hardcopy=no
      for i in {1..5}; do
        [[ -e hardcopy ]] && {
          i="${i}"
          hardcopy=yes
          printf 'hardcopy found\n'
          break
        }
        printf 'hardcopy not found\n'
        sleep .5
      done
      [[ ${hardcopy} == "yes" ]] && break
      printf 'creating hardcopy - why!'
      screen -S screencast -X hardcopy -h hardcopy
    done
    status=$(classify_status)
    probability=$(classify_probability)
    save_hardcopy "${x}" "${status}" "${probability}"
    printf 'Test %d status: %s (%s)\n' "${x}" "${status}" "${probability}"
  done
}

main "$@"

# vim:ft=sh:sw=2:et:ts=2:
