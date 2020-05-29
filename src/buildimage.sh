# BI - Build Image

# _BI is an associative array that holds data specific to building an image.
declare -A _BI

# Declare externally defined variables ----------------------------------------

# Defined in GL (globals.sh)
declare OK ERROR STDERR STOP TRUE FALSE

# Getters/Setters -------------------------------------------------------------

# BI_setflag_useprebuiltimage setter sets the useprebuiltimage array item.
# This is called by the parser, via a callback in _BI_new.
BI_setflag_useprebuiltimage() {
  _BI[useprebuiltimage]="$1"
}

# BI_k8sver getter outputs the value of the _BI[k8sver], the kubernetes version
# to be installed.
# Args: None expected.
BI_k8sver() {
  printf '%s' "${_BI[baseimagename]}"
}

# BI_baseimagename getter outputs the value of the _BI[baseimagename].
# Args: None expected.
BI_baseimagename() {
  printf '%s' "${_BI[baseimagename]}"
}

# Public Functions ------------------------------------------------------------

# BI_usage outputs help text for the build image component.
# It is called by PA_usage(), via a callback in _BI_new.
# Args: None expected.
BI_usage() {

  cat <<'EnD'
BUILD subcommands are:
 
  image - Creates the docker 'mok-centos-7' container image.
 
build image options:
 
 Format:
  build image

 Flags:
  --tailf - Show the build output whilst building.
  --get-prebuilt-image - Instead of building a 'node' image
         locally, download it from a container registry instead.

EnD
}

# BI_cleanup removes temporary files created during the build.
# This function is called by the 'MA_cleanup' trap only.
# Args: None expected.
BI_cleanup() {
  [[ -e ${_BI[dockerbuildtmpdir]} ]] &&
    [[ ${_BI[dockerbuildtmpdir]} == "/var/tmp/"* ]] && {
    rm -rf "${_BI[dockerbuildtmpdir]}" || {
      printf 'ERROR: "rm -rf %s" failed.\n' "${_BI[dockerbuildtmpdir]}" \
        >"${STDERR}"
      err || return
    }
  }
}

# BI_check_valid_options checks if arg1 is in a list of valid build image
# options. This function is called by the parser, via a callback in _BI_new.
# Args: arg1 - the option to check.
#       arg2 - value of the item to be set, optional
BI_process_options() {

  case "$1" in
  -h | --help)
    BI_usage
    return "${STOP}"
    ;;
  --tailf)
    _BI[tailf]="${TRUE}"
    return "${OK}"
    ;;
  --get-prebuilt-image)
    _BI[useprebuiltimage]="${TRUE}"
    return "${OK}"
    ;;
  *)
    BI_usage
    printf 'ERROR: "%s" is not a valid "build" option.\n' "${1}" \
      >"${STDERR}"
    return "${ERROR}"
    ;;
  esac
}

# BI_run builds the base image used for masters and workers.
# This function is called in main.sh.
# Args: None expected.
BI_run() {

  _BI_sanity_checks || return

  [[ ${_BI[tailf]} == "${TRUE}" ]] && {
    UT_set_tailf "${TRUE}" || err || return
  }

  local retval=0
  _BI_build_container_image
  retval=$?

  if [[ ${retval} -eq ${OK} ]]; then
    : # We only need the tick - no text
  else
    printf 'Image build failed\n' >"${STDERR}"
    err
  fi

  return "${retval}"
}

# Private Functions -----------------------------------------------------------

# _BI_new resets the initial values for the _BI associative array.
# Args: None expected.
_BI_new() {
  _BI[tailf]="${FALSE}"
  _BI[k8sver]="1.18.3"
  _BI[baseimagename]="mok-centos-7"
  _BI[useprebuiltimage]=
  _BI[dockerbuildtmpdir]=
  _BI[runwithprogress_output]=

  # Program the parser's state machine
  PA_add_state "COMMAND" "build" "SUBCOMMAND" ""
  PA_add_state "SUBCOMMAND" "buildimage" "END" ""

  # Set up the parser's option callbacks
  PA_add_option_callback "build" "BI_process_options" || return
  PA_add_option_callback "buildimage" "BI_process_options" || return

  # Set up the parser's usage callbacks
  PA_add_usage_callback "build" "BI_usage" || return
  PA_add_usage_callback "buildimage" "BI_usage" || return
}

# BI_sanity_checks is expected to run some quick and simple checks to
# see if it has all it's key components. For build image this does nothing.
# This function should not be deleted as it is called in main.sh.
# Args: None expected.
_BI_sanity_checks() { :; }

# _BI_build_container_image creates the docker build directory in
# dockerbuildtmpdir then calls docker build to build the image.
# Args: No args expected.
_BI_build_container_image() {

  local cmd retval tagname buildargs text buildtype

  _BI_create_docker_build_dir || return

  buildargs=$(_BI_get_build_args_for_k8s_ver "${_BI[k8sver]}") || return
  tagname="${_BI[baseimagename]}-v${_BI[k8sver]}"

  local imgprefix
  imgprefix=$(CU_imgprefix) || err || return
  if [[ -z ${_BI[useprebuiltimage]} ]]; then
    buildtype="create"
    cmd="docker build \
      -t "${imgprefix}local/${tagname}" \
      --force-rm \
      ${buildargs} \
      ${_BI[dockerbuildtmpdir]}/${_BI[baseimagename]}"
    text="Creating"
  else
    buildtype="download"
    cmd="docker pull mclarkson/${tagname}"
    text="Downloading"
  fi

  UT_run_with_progress \
    "    ${text} base image, '${tagname}'" "${cmd}"

  retval=$?
  [[ ${retval} -ne ${OK} ]] && {
    local runlogfile
    runlogfile=$(UT_runlogfile) || err || return
    printf 'ERROR: Docker returned an error, shown below\n\n' >"${STDERR}"
    cat "${runlogfile}" >"${STDERR}"
    printf '\n' >"${STDERR}"
    return "${ERROR}"
  }

  [[ ${buildtype} == "create" ]] && {
    cmd="_BI_modify_container_image"

    UT_run_with_progress \
      "    Modifying base image (pulling kubernetes images)" "${cmd}"

    retval=$?
    [[ ${retval} -ne ${OK} ]] && {
      local runlogfile
      runlogfile=$(UT_runlogfile) || err || return
      printf 'ERROR: Docker returned an error, shown below\n\n' >"${STDERR}"
      cat "${runlogfile}" >"${STDERR}"
      printf '\n' >"${STDERR}"
      return "${ERROR}"
    }
  }

  return "${OK}"
}

# _BI_modify_container_image starts a container suitable for running kubernetes
# components (since the docker/podman build environment isn't suitable), makes
# some modifications and then 'commits' the image. The modifications allow
# `mokctl create ...` to complete more quickly.
# Args: No args expected.
_BI_modify_container_image() {

  # Delete container, just in case it was left behind
  docker stop -t 5 mok-build-modify &>/dev/null
  docker rm mok-build-modify &>/dev/null

  # Start container
  CU_create_container "mok-build-modify" "mok-build-modify" "${_BI[k8sver]}" ||
    return

  # Wait for crio to become ready
  printf '\n\n ** WAITING FOR CRIO TO BECOME READY **\n\n'
  while ! docker exec mok-build-modify systemctl status crio; do
    sleep 1
    [[ ${counter} -gt 10 ]] && {
      printf '\nERROR: CRI-O did not start after %d tries.\n' "${counter}"
      err || return
    }
    ((counter++))
  done

  # Modify container
  docker exec mok-build-modify kubeadm config images pull || return

  # Stop container
  docker stop -t 5 "mok-build-modify"

  # Write image
  local imgprefix tagname
  imgprefix=$(CU_imgprefix) || err || return
  tagname="${_BI[baseimagename]}-v${_BI[k8sver]}"
  docker commit mok-build-modify "${imgprefix}local/${tagname}" || return

  # Delete container, just in case it was left behind
  docker stop -t 5 mok-build-modify
  docker rm mok-build-modify || err || return

  return "${OK}"
}

# _BI_get_build_args_for_k8s_ver sets the buildargs variable that is added
# to the 'podman build ...' command line.
# Args: None expected
_BI_get_build_args_for_k8s_ver() {

  local buildargs

  case "${_BI[k8sver]}" in
  "1.18.2" | "1.18.3")
    buildargs="--build-arg"
    buildargs="${buildargs} CRIO_VERSION=1.18"
    buildargs="${buildargs} --build-arg"
    buildargs="${buildargs} CRICTL_VERSION=v1.18.0"
    buildargs="${buildargs} --build-arg"
    buildargs="${buildargs} K8SBINVER=-1.18.3"
    ;;
  *)
    printf 'INTERNAL ERROR: This should not happen.\n' >"${STDERR}"
    err || return
    ;;
  esac

  printf '%s' "${buildargs}"
}

# _BI_create_docker_build_dir creates a docker build directory in
# /var/tmp/tmp.XXXXXXXX
# Args: None expected
_BI_create_docker_build_dir() {

  _BI[dockerbuildtmpdir]="$(mktemp -d -p /var/tmp)" || {
    printf 'ERROR: mktmp failed.\n' >"${STDERR}"
    err || return
  }

  # The following comments should not be removed or changed.
  # embed-dockerfile.sh adds a base64 encoded tarball and
  # unpacking code between them.

  #mok-centos-7-tarball-start
  #mok-centos-7-tarball-end
}

# Initialise _BI
_BI_new || exit 1

# vim helpers -----------------------------------------------------------------
#include globals.sh
# vim:ft=sh:sw=2:et:ts=2:
