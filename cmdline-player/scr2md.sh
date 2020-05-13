#!/bin/bash
set -e

[[ -z $1 ]] && {
  printf 'Output a .scr file as a .md file'
  printf 'Usage "%s <FILE.scr>"' "$(basename "$0")"
  exit 1
}

file="$1"

(
  printf '# Install mokctl on Linux\n\n```bash\n'
  grep -v '^screencast' "$file"
  printf '\n```\n'
) >"${file%.*}.md"
