#!/bin/bash
set -e

[[ -z $1 ]] && {
  printf 'Output a .scr file as a .md file'
  printf 'Usage "%s <FILE.scr> [\"TITLE\"]"' "$(basename "$0")"
  exit 1
}

file="$1"
title="$2"

cat <<EnD >"${file%.*}.md"
# $title

![](../docs/images/$(basename ${file%.*}.gif))

View the [screencast file](../cmdline-player/$(basename ${file%.*}.scr))

\`\`\`bash
$(grep -v '^screencast' "$file")
\`\`\`
EnD
