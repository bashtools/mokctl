# PA - PArser

# PA is holds data specific to parsing the command line arguments.
declare -A PA

# Declare externally defined variables ----------------------------------------

# Defined in ER (error.sh)
declare OK ERROR TRUE STOP STDERR

# Getters/Setters -------------------------------------------------------------

# Public Functions ------------------------------------------------------------

# PA_init sets the initial values for the PArsers associative array.
# Args: None expected.
PA_init() {

  PA[command]=
  PA[subcommand]=
}

# ---------------------------------------------------------------------------
PA_parse_options() {

  # Uses a state machine to check all command line arguments
  # Args:
  #   arg1 - The arguments given to mokctl by the user on the command line

  set -- "$@"
  local ARGN=$#
  while [ "${ARGN}" -ne 0 ]; do
    case "${1}" in
    --skipmastersetup)
      _PA_verify_option '--skipmastersetup' || return
      #CREATE_CLUSTER_SKIPMASTERSETUP="${TRUE}"
      ;;
    --skipworkersetup)
      _PA_verify_option '--skipworkersetup' || return
      #CREATE_CLUSTER_SKIPWORKERSETUP=$TRUE
      ;;
    --skiplbsetup)
      _PA_verify_option '--skiplbsetup' || return
      #CREATE_CLUSTER_SKIPLBSETUP="$TRUE"
      ;;
    --with-lb)
      _PA_verify_option '--with-lb' || return
      #CREATE_CLUSTER_WITH_LB="$TRUE"
      ;;
    --k8sver)
      _PA_verify_option '--k8sver' || return
      # enable later -> BUILD_IMAGE_K8SVER="$1"
      shift
      ;;
    --get-prebuilt-image)
      _PA_verify_option '--get-prebuilt-image' || return
      BI_setflag_useprebuiltimage "${TRUE}"
      ;;
    --help) ;&
    -h)
      _PA_usage
      return "${STOP}"
      ;;
    --?*)
      _PA_usage
      printf 'Invalid option: "%s"\n' "$1" >"${STDERR}"
      return "${ERROR}"
      ;;
    *)
      case "${STATE}" in
      COMMAND)
        _PA_check_command_token "${1}"
        [[ $? -eq ${ERROR} ]] && {
          _PA_usage
          printf 'Invalid COMMAND, "%s".\n\n' "$1" >"${STDERR}"
          return "${ERROR}"
        }
        ;;
      SUBCOMMAND)
        _PA_check_subcommand_token "${1}"
        [[ $? -eq ${ERROR} ]] && {
          _PA_usage
          printf 'Invalid SUBCOMMAND for %s, "%s".\n\n' "${PA[command]}" "${1}" \
            >"${STDERR}"
          return "${ERROR}"
        }
        ;;
      OPTION)
        _PA_check_option_token "${1}"
        [[ $? -eq ${ERROR} ]] && {
          _PA_usage
          printf 'Invalid OPTION for %s %s, "%s".\n\n' "${PA[command]}" \
            "${PA[subcommand]}" "${1}" >"${STDERR}"
          return "${ERROR}"
        }
        ;;
      OPTION2)
        _PA_check_option2_token "$1"
        [[ $? -eq ${ERROR} ]] && {
          _PA_usage
          printf 'Invalid OPTION for %s %s, "%s".\n\n' "${PA[command]}" \
            "${PA[subcommand]}" "${1}" >"${STDERR}"
          return "${ERROR}"
        }
        ;;
      OPTION3)
        _PA_check_option3_token "${1}"
        [[ $? -eq ${ERROR} ]] && {
          _PA_usage
          printf 'Invalid OPTION for %s %s, "%s".\n\n' "${PA[command]}" \
            "${PA[subcommand]}" "${1}" >"${STDERR}"
          return "${ERROR}"
        }
        ;;
      END)
        _PA_usage
        printf 'ERROR No more options expected, "%s" is unexpected for "%s %s"\n' \
          "${1}" "${PA[command]}" "${PA[subcommand]}" >"${STDERR}"
        return "${ERROR}"
        ;;
      *)
        printf 'Internal ERROR. Invalid state "%s"\n' "${STATE}" >"${STDERR}"
        return "${ERROR}"
        ;;
      esac
      ;;
    esac
    shift 1
    ARGN=$((ARGN - 1))
  done

  [[ -z ${PA[command]} ]] && {
    _PA_usage
    printf 'No COMMAND supplied\n' >"${STDERR}"
    return "${ERROR}"
  }
  [[ -z ${PA[subcommand]} ]] && {
    _PA_usage
    printf 'No SUBCOMMAND supplied\n' >"${STDERR}"
    return "${ERROR}"
  }

  return "${OK}"
}

# Private Functions -----------------------------------------------------------

# _PA_usage outputs help text for a single component, if help was asked for when
# a command was specified, or for all components otherwise.
# Args: None expected.
_PA_usage() {

  case "${PA[command]}" in
  create)
    CC_usage
    return
    ;;
  delete)
    DE_usage
    return
    ;;
  build)
    BI_usage
    return
    ;;
  get)
    GE_usage
    return
    ;;
  exec)
    EX_usage
    return
    ;;
  *)
    printf 'INTERNAL ERROR: This should not happen.' >"${STDERR}"
    err || return
    ;;
  esac

  cat <<'EnD'

Usage: mokctl [-h] <command> [subcommand] [OPTIONS...]
 
Global options:
 
  --help
  -h     - This help text
 
Where command can be one of:
 
  create - Add item(s) to the system.
  delete - Delete item(s) from the system.
  build  - Build item(s) used by the system.
  get    - Get details about items in the system.
  exec   - 'Log in' to the container.

EnD

  # Output individual help pages
  CC_usage # <- create cluster
  DE_usage # <- delete cluster
  BI_usage # <- build image
  GE_usage # <- get
  EX_usage # <- exec

  cat <<'EnD'
EXAMPLES
 
Get a list of mok clusters
 
  mokctl get clusters
 
Build the image used for masters and workers:
 
  mokctl build image
 
Create a single node cluster:
Note that the master node will be made schedulable for pods.
 
  mokctl create cluster mycluster 1 0
 
Create a single master and single node cluster:
Note that the master node will NOT be schedulable for pods.
 
  mokctl create cluster mycluster 1 1
 
Delete a cluster:
 
  mokctl delete cluster mycluster

EnD
}

# ---------------------------------------------------------------------------
_PA_check_command_token() {

  # Check for a valid token in command state
  # Args:
  #   arg1 - token

  case "${1}" in
  create)
    PA[command]="create"
    STATE="SUBCOMMAND"
    ;;
  delete)
    PA[command]="delete"
    STATE="SUBCOMMAND"
    ;;
  build)
    PA[command]="build"
    STATE="SUBCOMMAND"
    ;;
  get)
    PA[command]="get"
    STATE="SUBCOMMAND"
    ;;
  exec)
    PA[command]="exec"
    PA[subcommand]="unused"
    STATE="OPTION"
    ;;
  *) return "${ERROR}" ;;
  esac
}

# ---------------------------------------------------------------------------
_PA_check_subcommand_token() {

  # Check for a valid token in subcommand state
  # Args:
  #   arg1 - token

  case "${PA[command]}" in
  create) _PA_check_create_subcommand_token "$1" ;;
  delete) _PA_check_delete_subcommand_token "$1" ;;
  build) _PA_check_build_subcommand_token "$1" ;;
  get) _PA_check_get_subcommand_token "$1" ;;
  *)
    printf 'INTERNAL ERROR: This should not happen.' >"${STDERR}"
    err || return
    ;;
  esac
}

# ---------------------------------------------------------------------------
_PA_check_create_subcommand_token() {

  # Check for a valid token in subcommand state
  # Args:
  #   arg1 - token

  case $1 in
  cluster) PA[subcommand]="cluster" ;;
  *) return "${ERROR}" ;;
  esac

  STATE="OPTION"

  return "${OK}"
}

# ---------------------------------------------------------------------------
_PA_check_delete_subcommand_token() {

  # Check for a valid token in subcommand state
  # Args:
  #   arg1 - token

  case $1 in
  cluster) PA[subcommand]="cluster" ;;
  *) return "${ERROR}" ;;
  esac

  STATE=OPTION
}

# ---------------------------------------------------------------------------
_PA_check_build_subcommand_token() {

  # Check for a valid token in subcommand state
  # Args:
  #   arg1 - token

  case $1 in
  image)
    PA[subcommand]="image"
    BI_init
    ;;
  *) return "${ERROR}" ;;
  esac

  STATE=END
}

# ---------------------------------------------------------------------------
_PA_check_get_subcommand_token() {

  # Check for a valid token in subcommand state
  # Args:
  #   arg1 - token

  case "${1}" in
  clusters) ;&
  cluster) PA[subcommand]="cluster" ;;
  *) return "${ERROR}" ;;
  esac

  STATE=OPTION
}

# ---------------------------------------------------------------------------
_PA_check_option_token() {

  # Check for a valid token in option state
  # Args:
  #   arg1 - token

  case "${PA[command]}" in
  create)
    case "${PA[subcommand]}" in
    cluster)
      #CREATE_CLUSTER_NAME="${1}"
      STATE="OPTION2"
      ;;
    *)
      printf 'INTERNAL ERROR: This should not happen.' >"${STDERR}"
      err || return
      ;;
    esac
    ;;
  delete)
    case "${PA[subcommand]}" in
    cluster)
      #DELETE_CLUSTER_NAME="${1}"
      STATE="END"
      ;;
    *)
      printf 'INTERNAL ERROR: This should not happen.' >"${STDERR}"
      err || return
      ;;
    esac
    ;;
  get)
    case "${PA[subcommand]}" in
    cluster)
      #GET_CLUSTER_NAME="${1}"
      STATE="END"
      ;;
    *)
      printf 'INTERNAL ERROR: This should not happen.' >"${STDERR}"
      err || return
      ;;
    esac
    ;;
  exec)
    ##EXEC_CONTAINER_NAME="${1}"
    STATE="END"
    ;;
  *)
    printf 'INTERNAL ERROR: This should not happen.' >"${STDERR}"
    err || return
    ;;
  esac
}

# ---------------------------------------------------------------------------
_PA_check_option2_token() {

  # Check for a valid token in option2 state
  # Args:
  #   arg1 - token

  case "${PA[command]}" in
  create)
    case "${PA[subcommand]}" in
    cluster)
      #CREATE_CLUSTER_NUM_MASTERS="$1"
      STATE="OPTION3"
      ;;
    *)
      printf 'INTERNAL ERROR: This should not happen.' >"${STDERR}"
      err || return
      ;;
    esac
    ;;
  delete)
    case "${PA[subcommand]}" in
    cluster)
      return "${ERROR}"
      ;;
    *)
      printf 'INTERNAL ERROR: This should not happen.' >"${STDERR}"
      err || return
      ;;
    esac
    ;;
  *)
    printf 'INTERNAL ERROR: This should not happen.' >"${STDERR}"
    err || return
    ;;
  esac
}

# ---------------------------------------------------------------------------
_PA_check_option3_token() {

  # Check for a valid token in option3 state
  # Args:
  #   arg1 - token

  case "${PA[command]}" in
  create)
    case "${PA[subcommand]}" in
    cluster)
      #CREATE_CLUSTER_NUM_WORKERS="$1"
      STATE="END"
      ;;
    *)
      printf 'INTERNAL ERROR: This should not happen.' >"${STDERR}"
      err || return
      ;;
    esac
    ;;
  delete)
    case "${PA[subcommand]}" in
    cluster)
      return "${ERROR}"
      ;;
    *)
      printf 'INTERNAL ERROR: This should not happen.' >"${STDERR}"
      err || return
      ;;
    esac
    ;;
  *)
    printf 'INTERNAL ERROR: This should not happen.' >"${STDERR}"
    err || return
    ;;
  esac
}

# ===========================================================================
#                              FLAG PROCESSING
# ===========================================================================

# ---------------------------------------------------------------------------
_PA_verify_option() {

  # Check that the sent option is valid for the command-subcommand or global
  # options.
  # Args:
  #   arg1 - The option to check.

  case "${PA[command]}${PA[subcommand]}" in
  create) ;& # Treat flags located just before
  delete) ;& # or just after COMMAND
  build) ;&  # as global options.
  get) ;&
  '')
    _PA_check_valid_global_opts "$1"
    ;;
  createcluster)
    _PA_check_valid_create_cluster_opts "$1"
    ;;
  deletecluster)
    _PA_check_valid_delete_cluster_opts "$1"
    ;;
  execcluster)
    _PA_check_valid_exec_cluster_opts "$1"
    ;;
  buildimage)
    BI_check_valid_options "$1"
    ;;
  getcluster)
    _PA_check_valid_get_cluster_opts "$1"
    ;;
  *)
    printf 'INTERNAL ERROR: This should not happen.' >"${STDERR}"
    err || return
    ;;
  esac && return

  return "${ERROR}"
}

# ---------------------------------------------------------------------------
_PA_check_valid_global_opts() {

  # Args:
  #   arg1 - The option to check.

  local int validopts=(
    "--help"
    "-h"
  )

  for int in "${validopts[@]}"; do
    [[ $1 == "${int}" ]] && return
  done

  _PA_usage
  printf 'ERROR: "%s" is not a valid global option.\n' "$1" >"${STDERR}"
  return "${ERROR}"
}

# ---------------------------------------------------------------------------
_PA_check_valid_create_cluster_opts() {

  # Args:
  #   arg1 - The option to check.

  local opt validopts=(
    "--help"
    "-h"
    "--skipmastersetup"
    "--skipworkersetup"
    "--skiplbsetup"
    "--k8sver"
    "--with-lb"
  )

  for opt in "${validopts[@]}"; do
    [[ $1 == "${opt}" ]] && return
  done

  _PA_usage
  printf 'ERROR: "%s" is not a valid "create cluster" option.\n' "$1" >"${STDERR}"
  return "${ERROR}"
}

# ---------------------------------------------------------------------------
_PA_check_valid_delete_cluster_opts() {

  # Args:
  #   arg1 - The option to check.

  local opt validopts=(
    "--help"
    "-h"
  )

  for opt in "${validopts[@]}"; do
    [[ $1 == "${opt}" ]] && return
  done

  _PA_usage
  printf 'ERROR: "%s" is not a valid "delete cluster" option.\n' "$1" \
    >"${STDERR}"
  return "${ERROR}"
}

# ---------------------------------------------------------------------------
_PA_check_valid_get_cluster_opts() {

  # Args:
  #   arg1 - The option to check.

  local opt validopts=(
    "--help"
    "-h"
  )

  for opt in "${validopts[@]}"; do
    [[ $1 == "${opt}" ]] && return
  done

  _PA_usage
  printf 'ERROR: "%s" is not a valid "get cluster" option.\n' "$1" >"${STDERR}"
  return "${ERROR}"
}

# ---------------------------------------------------------------------------
_PA_check_valid_exec_cluster_opts() {

  # Args:
  #   arg1 - The option to check.

  local opt validopts=(
    "--help"
    "-h"
  )

  for opt in "${validopts[@]}"; do
    [[ $1 == "${opt}" ]] && return
  done

  _PA_usage
  printf 'ERROR: "%s" is not a valid "get cluster" option.\n' "$1" \
    >"${STDERR}"
  return "${ERROR}"
}

# vim helpers -----------------------------------------------------------------
#include globals.sh
# vim:ft=sh:sw=2:et:ts=2:
