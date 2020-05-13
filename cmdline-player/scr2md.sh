#!/bin/bash
set -e

[[ -z $1 ]] && {
  printf 'Output a .scr file as a .md file'
  printf 'Usage "%s <FILE.scr> [\"TITLE\"]"' "$(basename "$0")"
  exit 1
}

file="$1"
title="$2"

(
  printf '# %s\n\n```bash\n' "$2"
  grep -v '^screencast' "$file"
  printf '\n```\n'
) >"${file%.*}.md"
