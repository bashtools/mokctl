#!/bin/bash
set -e

[[ -z $1 || -z $2 ]] && {
  printf 'Output a .scr file as a .md file'
  printf 'Usage "%s <FILE.scr> <\"TITLE\"> [MDFILE]"' "$(basename "$0")"
  exit 1
}

file="$1"
title="$2"
kthwmd="$3"

# Create the screencast file

cat <<EnD >"${file%.*}.md"
# $title

![](../docs/images/$(basename "${file%.*}.gif"))

View the [screencast file](../cmdline-player/$(basename "${file%.*}.scr"))

\`\`\`bash
$(grep -Ev '(^screencast|^.MD)' "$file")
\`\`\`
EnD

[[ -n $kthwmd ]] && {
  # Create the Markdown document

  grep -Ev '(^screencast |^#|^ *$)' "$file" |
    sed 's/^.MD *//' >"$kthwmd"
}

exit 0
