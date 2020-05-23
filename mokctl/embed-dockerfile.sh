a=$(tar cz "mok-centos-7$1" | base64 | sed 's/$/\\/')
sed -r '/mok-centos-7-tarball-start/, /mok-centos-7-tarball-end/ c \
  #mok-centos-7-tarball-start \
  cat <<'EnD' | base64 -d | tar xz -C "$DOCKERBUILDTMPDIR" \
'"$a"'
EnD\
  #mok-centos-7-tarball-end' mokctl/buildimage.sh >mokctl.deploy
