# shellcheck shell=bash disable=SC2148 disable=SC1078 disable=SC1079 disable=SC2026
a=$(tar cz "mokctl-image$1" | base64 | sed 's/$/\\/')
sed -r '/mokctl-image-tarball-start/, /mokctl-image-tarball-end/ c \
  #mokctl-image-tarball-start \
  cat <<'EnD' | base64 -d | tar xz -C "${_BI[dockerbuildtmpdir]}" \
'"$a"'
EnD\
  #mokctl-image-tarball-end' src/buildimage.sh >src/buildimage.deploy
