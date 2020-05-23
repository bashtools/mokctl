# PA - PArser

# PA is holds data specific to parsing the command line arguments.
declare -A PA

# Declare externally defined variables ----------------------------------------

# Defined in ER (error.sh)
declare OK ERROR TRUE STOP STDERR

# Getters/Setters -------------------------------------------------------------

# ---------------------------------------------------------------------------
PA_usage() {

  case "${PA[command]}" in
  create)
    CC_usage
    return "${OK}"
    ;;
  delete)
    DE_usage
    return "${OK}"
    ;;
  build)
    BI_usage
    return "${OK}"
    ;;
  get)
    GE_usage
    return "${OK}"
    ;;
  exec)
    EX_usage
    return "${OK}"
    ;;
  *)
    printf 'INTERNAL ERROR: This should not happen.' >"${STDERR}"
    err || return "${ERROR}"
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
PA_parse_options() {

  # Uses a state machine to check all command line arguments
  # Args:
  #   arg1 - The arguments given to mokctl by the user on the command line

  set -- "$@"
  local ARGN=$#
  while [ "${ARGN}" -ne 0 ]; do
    case "${1}" in
    --skipmastersetup)
      PA_verify_option '--skipmastersetup' || return "${ERROR}"
      #CREATE_CLUSTER_SKIPMASTERSETUP="${TRUE}"
      ;;
    --skipworkersetup)
      PA_verify_option '--skipworkersetup' || return "${ERROR}"
      #CREATE_CLUSTER_SKIPWORKERSETUP=$TRUE
      ;;
    --skiplbsetup)
      PA_verify_option '--skiplbsetup' || return "${ERROR}"
      #CREATE_CLUSTER_SKIPLBSETUP="$TRUE"
      ;;
    --with-lb)
      PA_verify_option '--with-lb' || return "${ERROR}"
      #CREATE_CLUSTER_WITH_LB="$TRUE"
      ;;
    --k8sver)
      PA_verify_option '--k8sver' || return "${ERROR}"
      # enable later -> BUILD_IMAGE_K8SVER="$1"
      shift
      ;;
    --get-prebuilt-image)
      PA_verify_option '--get-prebuilt-image' || return "${ERROR}"
      BI_set_useprebuiltimage "${TRUE}"
      ;;
    --help) ;&
    -h)
      PA_usage
      return "${STOP}"
      ;;
    --?*)
      PA_usage
      printf 'Invalid option: "%s"\n' "$1" >"${STDERR}"
      return "${ERROR}"
      ;;
    *)
      case "${STATE}" in
      COMMAND)
        PA_check_command_token "${1}"
        [[ $? -eq ${ERROR} ]] && {
          PA_usage
          printf 'Invalid COMMAND, "%s".\n\n' "$1" >"${STDERR}"
          return "${ERROR}"
        }
        ;;
      SUBCOMMAND)
        PA_check_subcommand_token "${1}"
        [[ $? -eq ${ERROR} ]] && {
          PA_usage
          printf 'Invalid SUBCOMMAND for %s, "%s".\n\n' "${COMMAND}" "${1}" \
            >"${STDERR}"
          return "${ERROR}"
        }
        ;;
      OPTION)
        PA_check_option_token "${1}"
        [[ $? -eq ${ERROR} ]] && {
          PA_usage
          printf 'Invalid OPTION for %s %s, "%s".\n\n' "${COMMAND}" \
            "${SUBCOMMAND}" "${1}" >"${STDERR}"
          return "${ERROR}"
        }
        ;;
      OPTION2)
        PA_check_option2_token "$1"
        [[ $? -eq ${ERROR} ]] && {
          PA_usage
          printf 'Invalid OPTION for %s %s, "%s".\n\n' "${COMMAND}" \
            "${SUBCOMMAND}" "${1}" >"${STDERR}"
          return "${ERROR}"
        }
        ;;
      OPTION3)
        PA_check_option3_token "${1}"
        [[ $? -eq ${ERROR} ]] && {
          PA_usage
          printf 'Invalid OPTION for %s %s, "%s".\n\n' "${COMMAND}" \
            "${SUBCOMMAND}" "${1}" >"${STDERR}"
          return "${ERROR}"
        }
        ;;
      END)
        PA_usage
        printf 'ERROR No more options expected, "%s" is unexpected for "%s %s"\n' \
          "${1}" "${COMMAND}" "${SUBCOMMAND}" >"${STDERR}"
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

  [[ -z ${COMMAND} ]] && {
    PA_usage
    printf 'No COMMAND supplied\n' >"${STDERR}"
    return "${ERROR}"
  }
  [[ -z ${SUBCOMMAND} ]] && {
    PA_usage
    printf 'No SUBCOMMAND supplied\n' >"${STDERR}"
    return "${ERROR}"
  }

  return "${OK}"
}

# ===========================================================================
#                    COMMAND, SUBCOMMAND, OPTION PROCESSING
# ===========================================================================

# ---------------------------------------------------------------------------
PA_check_command_token() {

  # Check for a valid token in command state
  # Args:
  #   arg1 - token

  case "${1}" in
  create)
    COMMAND="create"
    STATE="SUBCOMMAND"
    ;;
  delete)
    COMMAND="delete"
    STATE="SUBCOMMAND"
    ;;
  build)
    COMMAND="build"
    STATE="SUBCOMMAND"
    ;;
  get)
    COMMAND="get"
    STATE="SUBCOMMAND"
    ;;
  exec)
    COMMAND="exec"
    SUBCOMMAND="unused"
    STATE="OPTION"
    ;;
  *) return "${ERROR}" ;;
  esac
}

# ---------------------------------------------------------------------------
PA_check_subcommand_token() {

  # Check for a valid token in subcommand state
  # Args:
  #   arg1 - token

  case "${COMMAND}" in
  create) PA_check_create_subcommand_token "$1" ;;
  delete) PA_check_delete_subcommand_token "$1" ;;
  build) PA_check_build_subcommand_token "$1" ;;
  get) PA_check_get_subcommand_token "$1" ;;
  *)
    printf 'INTERNAL ERROR: This should not happen.' >"${STDERR}"
    err || return "${ERROR}"
    ;;
  esac
}

# ---------------------------------------------------------------------------
PA_check_create_subcommand_token() {

  # Check for a valid token in subcommand state
  # Args:
  #   arg1 - token

  case $1 in
  cluster) SUBCOMMAND="cluster" ;;
  *) return "${ERROR}" ;;
  esac

  STATE="OPTION"

  return "${OK}"
}

# ---------------------------------------------------------------------------
PA_check_delete_subcommand_token() {

  # Check for a valid token in subcommand state
  # Args:
  #   arg1 - token

  case $1 in
  cluster) SUBCOMMAND="cluster" ;;
  *) return "${ERROR}" ;;
  esac

  STATE=OPTION
}

# ---------------------------------------------------------------------------
PA_check_build_subcommand_token() {

  # Check for a valid token in subcommand state
  # Args:
  #   arg1 - token

  case $1 in
  image)
    SUBCOMMAND="image"
    BI_init
    ;;
  *) return "${ERROR}" ;;
  esac

  STATE=END
}

# ---------------------------------------------------------------------------
PA_check_get_subcommand_token() {

  # Check for a valid token in subcommand state
  # Args:
  #   arg1 - token

  case "${1}" in
  clusters) ;&
  cluster) SUBCOMMAND="cluster" ;;
  *) return "${ERROR}" ;;
  esac

  STATE=OPTION
}

# ---------------------------------------------------------------------------
PA_check_option_token() {

  # Check for a valid token in option state
  # Args:
  #   arg1 - token

  case "${COMMAND}" in
  create)
    case "${SUBCOMMAND}" in
    cluster)
      #CREATE_CLUSTER_NAME="${1}"
      STATE="OPTION2"
      ;;
    *)
      printf 'INTERNAL ERROR: This should not happen.' >"${STDERR}"
      err || return "${ERROR}"
      ;;
    esac
    ;;
  delete)
    case "${SUBCOMMAND}" in
    cluster)
      #DELETE_CLUSTER_NAME="${1}"
      STATE="END"
      ;;
    *)
      printf 'INTERNAL ERROR: This should not happen.' >"${STDERR}"
      err || return "${ERROR}"
      ;;
    esac
    ;;
  get)
    case "${SUBCOMMAND}" in
    cluster)
      #GET_CLUSTER_NAME="${1}"
      STATE="END"
      ;;
    *)
      printf 'INTERNAL ERROR: This should not happen.' >"${STDERR}"
      err || return "${ERROR}"
      ;;
    esac
    ;;
  exec)
    ##EXEC_CONTAINER_NAME="${1}"
    STATE="END"
    ;;
  *)
    printf 'INTERNAL ERROR: This should not happen.' >"${STDERR}"
    err || return "${ERROR}"
    ;;
  esac
}

# ---------------------------------------------------------------------------
PA_check_option2_token() {

  # Check for a valid token in option2 state
  # Args:
  #   arg1 - token

  case "${COMMAND}" in
  create)
    case "${SUBCOMMAND}" in
    cluster)
      #CREATE_CLUSTER_NUM_MASTERS="$1"
      STATE="OPTION3"
      ;;
    *)
      printf 'INTERNAL ERROR: This should not happen.' >"${STDERR}"
      err || return "${ERROR}"
      ;;
    esac
    ;;
  delete)
    case "${SUBCOMMAND}" in
    cluster)
      return "${ERROR}"
      ;;
    *)
      printf 'INTERNAL ERROR: This should not happen.' >"${STDERR}"
      err || return "${ERROR}"
      ;;
    esac
    ;;
  *)
    printf 'INTERNAL ERROR: This should not happen.' >"${STDERR}"
    err || return "${ERROR}"
    ;;
  esac
}

# ---------------------------------------------------------------------------
PA_check_option3_token() {

  # Check for a valid token in option3 state
  # Args:
  #   arg1 - token

  case "${COMMAND}" in
  create)
    case "${SUBCOMMAND}" in
    cluster)
      #CREATE_CLUSTER_NUM_WORKERS="$1"
      STATE="END"
      ;;
    *)
      printf 'INTERNAL ERROR: This should not happen.' >"${STDERR}"
      err || return "${ERROR}"
      ;;
    esac
    ;;
  delete)
    case "${SUBCOMMAND}" in
    cluster)
      return "${ERROR}"
      ;;
    *)
      printf 'INTERNAL ERROR: This should not happen.' >"${STDERR}"
      err || return "${ERROR}"
      ;;
    esac
    ;;
  *)
    printf 'INTERNAL ERROR: This should not happen.' >"${STDERR}"
    err || return "${ERROR}"
    ;;
  esac
}

# ===========================================================================
#                              FLAG PROCESSING
# ===========================================================================

# ---------------------------------------------------------------------------
PA_verify_option() {

  # Check that the sent option is valid for the command-subcommand or global
  # options.
  # Args:
  #   arg1 - The option to check.

  case "${COMMAND}${SUBCOMMAND}" in
  create) ;& # Treat flags located just before
  delete) ;& # or just after COMMAND
  build) ;&  # as global options.
  get) ;&
  '')
    PA_check_valid_global_opts "$1"
    ;;
  createcluster)
    PA_check_valid_create_cluster_opts "$1"
    ;;
  deletecluster)
    PA_check_valid_delete_cluster_opts "$1"
    ;;
  execcluster)
    PA_check_valid_exec_cluster_opts "$1"
    ;;
  buildimage)
    BI_check_valid_options "$1"
    ;;
  getcluster)
    PA_check_valid_get_cluster_opts "$1"
    ;;
  *)
    printf 'INTERNAL ERROR: This should not happen.' >"${STDERR}"
    err || return "${ERROR}"
    ;;
  esac && return "${OK}"

  return "${ERROR}"
}

# ---------------------------------------------------------------------------
PA_check_valid_global_opts() {

  # Args:
  #   arg1 - The option to check.

  local int validopts=(
    "--help"
    "-h"
  )

  for int in "${validopts[@]}"; do
    [[ $1 == "${int}" ]] && return "${OK}"
  done

  PA_usage
  printf 'ERROR: "%s" is not a valid global option.\n' "$1" >"${STDERR}"
  return "${ERROR}"
}

# ---------------------------------------------------------------------------
PA_check_valid_create_cluster_opts() {

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
    [[ $1 == "${opt}" ]] && return "${OK}"
  done

  PA_usage
  printf 'ERROR: "%s" is not a valid "create cluster" option.\n' "$1" >"${STDERR}"
  return "${ERROR}"
}

# ---------------------------------------------------------------------------
PA_check_valid_delete_cluster_opts() {

  # Args:
  #   arg1 - The option to check.

  local opt validopts=(
    "--help"
    "-h"
  )

  for opt in "${validopts[@]}"; do
    [[ $1 == "${opt}" ]] && return "${OK}"
  done

  PA_usage
  printf 'ERROR: "%s" is not a valid "delete cluster" option.\n' "$1" \
    >"${STDERR}"
  return "${ERROR}"
}

# ---------------------------------------------------------------------------
PA_check_valid_get_cluster_opts() {

  # Args:
  #   arg1 - The option to check.

  local opt validopts=(
    "--help"
    "-h"
  )

  for opt in "${validopts[@]}"; do
    [[ $1 == "${opt}" ]] && return "${OK}"
  done

  PA_usage
  printf 'ERROR: "%s" is not a valid "get cluster" option.\n' "$1" >"${STDERR}"
  return "${ERROR}"
}

# ---------------------------------------------------------------------------
PA_check_valid_exec_cluster_opts() {

  # Args:
  #   arg1 - The option to check.

  local opt validopts=(
    "--help"
    "-h"
  )

  for opt in "${validopts[@]}"; do
    [[ $1 == "${opt}" ]] && return "${OK}"
  done

  PA_usage
  printf 'ERROR: "%s" is not a valid "get cluster" option.\n' "$1" \
    >"${STDERR}"
  return "${ERROR}"
}

# vim helpers -----------------------------------------------------------------
#include globals.sh
# vim:ft=sh:sw=2:et:ts=2:
