# BI - Build Image

# BI is an associative array that holds data specific to building an image.
declare -A BI

# Declare externally defined variables ----------------------------------------

#declare -A CT # <- container
#declare -A UT  # <- utility
#declare -A ER # <- error

# Getters/Setters -------------------------------------------------------------

# BI_set_useprebuiltimage setter sets the useprebuiltimage array item.
# This is called by the parser.
BI_set_useprebuiltimage() {
  BI[useprebuiltimage]="$1"
}

# Public Functions ------------------------------------------------------------

# BI_init sets the initial values for the BI associative array.
# This function is called by parse_options once it knows which component is
# being requested but before it sets any array members.
# Args: None expected.
BI_init() {

  BI[subcommand]=
  BI[build_image_k8sver]=
  BI[baseimagename]="mok-centos-7"
  BI[useprebuiltimage]=
  BI[dockerbuildtmpdir]=
  BI[runwithprogress_output]=
}

# BI_build_usage outputs help text for the build image component.
# It is called by usage().
# Args: None expected.
BI_build_usage() {

  cat <<'EnD'
BUILD subcommands are:
 
  image - Creates the docker 'mok-centos-7' container image.
 
build image options:
 
 Format:
  build image

 Flags:
  --get-prebuilt-image - Instead of building a 'node' image
         locally, download it from a container registry instead.

EnD
}

# BI_cleanup removes temporary files created during the build.
# This function is called by the 'cleanup' trap only.
# Args: None expected.
BI_cleanup() {
  [[ -e ${BI[dockerbuildtmpdir]} ]] &&
    [[ ${BI[dockerbuildtmpdir]} == "/var/tmp/"* ]] && {
    rm -rf "${BI[dockerbuildtmpdir]}"
  }
}

# BI_check_valid_options checks if arg1 is in a list of valid build image
# options. This function is called by the parser.
# Args: arg1 - the option to check.
BI_check_valid_options() {

  local opt validopts=(
    "--help"
    "-h"
    "--get-prebuilt-image"
  )

  for opt in "${validopts[@]}"; do
    [[ ${1} == "${opt}" ]] && return "${ER[OK]}"
  done

  usage
  printf 'ERROR: "%s" is not a valid "build image" option.\n' "${1}" >"${ER[E]}"
  return "${ER[ERROR]}"
}

# BI_sanity_checks is expected to run some quick and simple checks to
# see if it has all it's key components. For build image this does nothing.
# This function should not be deleted as it is called in main.sh.
# Args: None expected.
BI_sanity_checks() { :; }

# BI_build_image builds the base image used for masters and workers.
# This function is called in main.sh.
# Args: None expected.
BI_build_image() {

  local retval=0

  _BI_build_container_image
  retval=$?

  if [[ ${retval} -eq 0 ]]; then
    : # We only need the tick - no text
  else
    printf 'Image build failed\n' >"${E}"
  fi

  return "${retval}"
}

# Private Functions -----------------------------------------------------------

# _BI_build_container_image creates the docker build directory in
# dockerbuildtmpdir then calls docker build to build the image.
# Args: No args expected.
_BI_build_container_image() {

  local cmd retval tagname buildargs text

  _BI_create_docker_build_dir || return

  buildargs=$(_BI_get_build_args_for_k8s_ver "${BI[build_image_k8sver]}") || return
  tagname="${BI[baseimagename]}-v${BI[build_image_k8sver]}"

  if [[ -z ${BI[useprebuiltimage]} ]]; then
    cmd="docker build \
    -t "${CT[imgprefix]}local/${tagname}" \
    --force-rm \
    ${buildargs} \
    ${BI[DOCKERBUILDTMPDIR]}/${BI[baseimagename]}"
    text="Creating"
  else
    cmd="docker pull mclarkson/mok-centos-7-v1.18.2"
    text="Downloading"
  fi

  run_with_progress \
    "    ${text} base image, '${tagname}'" "${cmd}"

  retval=$?
  [[ ${retval} -ne 0 ]] && {
    printf 'ERROR: Docker returned an error, shown below\n\n' >"${ER[stderr]}"
    cat "${RUNWITHPROGRESS_OUTPUT}" >"${ER[stderr]}"
    printf '\n' >"${ER[stderr]}"
    return "${ER[ERROR]}"
  }

  return "${retval}"
}

# _BI_get_build_args_for_k8s_ver sets the buildargs variable that is added
# to the 'podman build ...' command line.
# Args: None expected
_BI_get_build_args_for_k8s_ver() {

  local buildargs

  case "${BI[build_image_k8sver]}" in
  "1.18.2")
    buildargs="--build-arg"
    buildargs="${buildargs} CRIO_VERSION=1.18"
    buildargs="${buildargs} --build-arg"
    buildargs="${buildargs} CRICTL_VERSION=v1.18.0"
    buildargs="${buildargs} --build-arg"
    buildargs="${buildargs} K8SBINVER=-1.18.2"
    ;;
  *)
    printf 'INTERNAL ERROR: This should not happen.'
    err || return "${ERROR}"
    ;;
  esac

  printf '%s' "${buildargs}"
}

# _BI_create_docker_build_dir creates a docker build directory in
# /var/tmp/tmp.XXXXXXXX
# Args: None expected
_BI_create_docker_build_dir() {

  BI[dockerbuildtmpdir]="$(mktemp -d -p /var/tmp)" || {
    printf 'ERROR: mktmp failed.\n' >"${ER[E]}"
    err || return
  }

  # The following comments should not be removed or changed.
  # embed-dockerfile.sh adds a base64 encoded tarball and
  # unpacking code between them.

  #mok-centos-7-tarball-start
  #mok-centos-7-tarball-end
}

# vim helpers -----------------------------------------------------------------

# The following lines allow the use of '[C-i' and '[I' (do ':help [I') in vim.
#include container.sh
#include createcluster.sh
#include deletecluster.sh
#include embed-dockerfile.sh
#include error.sh
#include exec.sh
#include getcluster.sh
#include main.sh
#include parser.sh
#include util.sh

# vim:ft=sh:sw=2:et:ts=2:
