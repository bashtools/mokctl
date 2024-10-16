# shellcheck shell=bash disable=SC2148 disable=SC1078 disable=SC1079 disable=SC2026
a=$(tar cz "mok-image$1" | base64 | sed 's/$/\\/')
sed -r '/mok-image-tarball-start/, /mok-image-tarball-end/ c \
  #mok-image-tarball-start \
  cat <<'EnD' | base64 -d | tar xz -C "${_BI[dockerbuildtmpdir]}" \
'"$a"'
EnD\
  #mok-image-tarball-end' src/buildimage.sh >src/buildimage.deploy
