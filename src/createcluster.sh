# CC - Create Cluster

# CC is an associative array that holds data specific to creating a cluster.
declare -A CC

# Declare externally defined variables ----------------------------------------

# Defined in GL (globals.sh)
declare OK ERROR STDERR

# Getters/Setters -------------------------------------------------------------

# CC_setflag_skipmastersetup setter sets the skipmastersetup array item.
# This function is called by the parser.
CC_setflag_skipmastersetup() {
  CC[skipmastersetup]="$1"
}

# CC_setflag_skipworkersetup setter sets the skipmastersetup array item.
# This function is called by the parser.
CC_setflag_skipworkersetup() {
  CC[skipworkersetup]="$1"
}

# CC_setflag_skiplbsetup setter sets the skipmastersetup array item.
# This function is called by the parser.
CC_setflag_skiplbsetup() {
  CC[skiplbsetup]="$1"
}

# CC_setflag_withlb setter sets the skipmastersetup array item.
# This function is called by the parser.
CC_setflag_withlb() {
  CC[withlb]="$1"
}

# CC_set_clustername setter sets the clustername array item.
CC_set_clustername() {
  CC[clustername]="$1"
}

# CC_set_nummasters setter sets the nummasters array item.
# This function is called by the parser.
CC_set_nummasters() {
  CC[nummasters]="$1"
}

# CC_set_numworkers setter sets the numworkers array item.
# This function is called by the parser.
CC_set_numworkers() {
  CC[numworkers]="$1"
}

# Public Functions ------------------------------------------------------------

# CC_init sets the initial values for the CC associative array.
# This function is called by parse_options once it knows which component is
# being requested but before it sets any array members.
# Args: None expected.
CC_init() {

  CC[k8sver]="1.18.2"
}

# CC_check_valid_options checks if arg1 is in a list of valid create cluster
# options. This function is called by the parser.
# Args: arg1 - the option to check.
CC_check_valid_options() {

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

# CC_usage outputs help text for the create cluster component.
# It is called by PA_usage().
# Args: None expected.
CC_usage() {

  cat <<'EnD'
CREATE subcommands are:
 
  cluster - Create a local kubernetes cluster.
 
create cluster [flags] options:
 
 Format:
  create cluster NAME NUM_MASTERS NUM_WORKERS
  NAME        - The name of the cluster. This will be used as
                the prefix in the name for newly created
                docker containers.
  NUM_MASTERS - The number of master containers.
  NUM_WORKERS - The number of worker containers. If NUM_WORKERS is
                zero then the 'node-role.kubernetes.io/master' taint
                will be removed from master nodes so that pods are
                schedulable.
 
 Flags:
  --skipmastersetup - Create the master container but don't set it
         up. Useful for manually installing kubernetes. Kubeadm, 
         kubelet and kubectl will be installed at the requested 
         version. With this option the worker will also be skipped.
         See also '--k8sver' flag.
  --skipworkersetup - The same as '--skipmastersetup', but skips
         setting up the worker only.
  --with-lb - Add a haproxy load balancer. The software will be installed
         and set up to reverse proxy to the master node(s), unless
         --skiplbsetup is used.
  --k8sver VERSION - Unimplemented.

EnD
}

# CC_sanity_checks is expected to run some quick and simple checks to see if it
# has all it's key components. This function is called in main.sh. At this
# point all parsing has been completed and flags set.
# Args: None expected.
# ---------------------------------------------------------------------------
CC_sanity_checks() {

  if [[ -z ${CC[clustername]} ]]; then
    usage
    printf 'Please provide the Cluster NAME to create.\n' >"${STDERR}"
    return "${ERROR}"
  fi

  if [[ -z ${CC[nummasters]} || ${CC[nummasters]} -le 0 ]]; then
    usage
    printf 'Please provide the number of Masters to create. Must be 1 or more.\n' \
      >"${STDERR}"
    return "${ERROR}"
  fi

  if [[ -z ${CC[numworkers]} ]]; then
    usage
    printf 'Please provide the number of Workers to create.\n' >"${STDERR}"
    return "${ERROR}"
  fi
}

# CC_cluster_create creates the kubernetes cluster.
# This function is called by main.sh.
# Args: None expected.
CC_cluster_create() {

  declare -i numnodes=0

  numnodes=$(get_cluster_size "${CC[clustername]}") || return

  [[ ${numnodes} -gt 0 ]] && {
    printf '\nERROR: Cluster, "%s", exists! Aborting.\n\n' "${CC[clustername]}" \
      >"${STDERR}"
    return "${ERROR}"
  }

  printf '\n'

  [[ ${CC[withlb]} -gt 0 ]] && {
    create_lb_node "${CC[nummasters]}" || return
  }

  [[ ${CC[nummasters]} -gt 0 ]] && {
    create_master_nodes "${CC[nummasters]}" || return
  }

  #[[ -z ${CC[skipmastersetup]} ]] && {
  #  # TODO Query the server for all pods ready instead
  #  run_with_progress \
  #    "    Waiting for master to be ready." \
  #    sleep 40
  #}

  [[ ${CC[withlb]} -gt 0 ]] && {
    setup_lb_node "${CC[nummasters]}" || return
  }

  [[ ${CC[numworkers]} -gt 0 ]] && {
    create_worker_nodes "${CC[numworkers]}" || return
  }

  printf '\n'

  [[ -z ${CC[skipmastersetup]} ]] && {
    printf 'Cluster, "%s", can be accessed using:\n\n' "${CC[clustername]}"
    printf 'export KUBECONFIG=/var/tmp/admin.conf\n\n'
  }

  return "${OK}"
}

# ---------------------------------------------------------------------------
create_lb_node() {

  # Create the load balancer nodes
  # Args:

  # Ceate container
  run_with_progress \
    "    Creating load balancer container, '${CC[clustername]}-lb'" \
    CU_create_container \
    "${CC[clustername]}-lb" \
    "$(CU_labelkey)=${CC[clustername]}" \
    "${CC[k8sver]}"

  [[ ${r} -ne 0 ]] && {
    printf '\n' >"$E"
    cat $RUNWITHPROGRESS_OUTPUT >"$E"
    printf '\nERROR: Set up failed. See above, and also in the file:' >"$E"
    printf '%s\n' "$RUNWITHPROGRESS_OUTPUT" >"$E"
    return $ERROR
  }

  return $OK
}

# ---------------------------------------------------------------------------
setup_lb_node() {

  # Create the load balancer nodes
  # Args:

  # Set up
  [[ -z $CREATE_CLUSTER_SKIPLBSETUP ]] && {
    run_with_progress \
      "    Setting up '${CC[clustername]}-lb'" \
      set_up_lb_node_real "${CC[clustername]}-lb"
    r=$?

    [[ $r -ne 0 ]] && {
      printf '\n' >"$E"
      cat $RUNWITHPROGRESS_OUTPUT >"$E"
      printf '\nERROR: Set up failed. See above, and also in the file:' >"$E"
      printf '%s\n' "$RUNWITHPROGRESS_OUTPUT" >"$E"
      return $ERROR
    }
  }

  return $OK
}

# ---------------------------------------------------------------------------
set_up_lb_node_real() {

  # Call the correct set up function based on the version
  # Args
  #   arg1 - the container ID to set up

  local setupfile nl idx masteriplist

  setupfile=$(mktemp -p /var/tmp) || {
    printf 'ERROR: mktmp failed.\n' >"$E"
    return $ERROR
  }

  masteriplist=
  nl=
  for idx in $(seq 1 "${CC[nummasters]}"); do
    ip=$(CU_get_container_ip "${CC[clustername]}-master-${idx}") || return
    masteriplist="${masteriplist}${nl}    server master-${idx} ${ip}:6443 check fall 3 rise 2"
    nl='\n'
  done

  cat <<EnD >"$setupfile"
# Disable ipv6
sysctl -w net.ipv6.conf.all.disable_ipv6=1
sysctl -w net.ipv6.conf.default.disable_ipv6=1

systemctl stop kubelet crio
systemctl disable kubelet crio

yum -y install haproxy

INTERNAL_IP=\$(ip ro get default 8.8.8.8 | head -n 1 | cut -f 7 -d " ")

cat <<EOF | tee /etc/haproxy/haproxy.cfg 
frontend kubernetes
    bind \$INTERNAL_IP:6443
    option tcplog
    mode tcp
    default_backend kubernetes-master-nodes
backend kubernetes-master-nodes
    mode tcp
    balance roundrobin
    option tcp-check
\$(echo -e "$masteriplist")
EOF

systemctl restart haproxy
systemctl enable haproxy

EnD

  docker cp "$setupfile" "$1":/root/setup.sh || err || {
    rm -f "$setupfile"
    return $ERROR
  }

  docker exec "$1" bash /root/setup.sh || err
}

# ---------------------------------------------------------------------------
create_master_nodes() {

  # Create the master nodes
  # Args:
  #   arg1 - number of master nodes to create

  declare -i int=0 r

  for int in $(seq 1 "$1"); do
    run_with_progress \
      "    Creating master container, '${CC[clustername]}-master-${int}'" \
      CU_create_container \
      "${CC[clustername]}-master-${int}" \
      "$(CU_labelkey)=${CC[clustername]}" \
      "${CC[k8sver]}"
    r=$?

    [[ $r -ne 0 ]] && {
      printf '\n'
      cat $RUNWITHPROGRESS_OUTPUT >"$E"
      rm $RUNWITHPROGRESS_OUTPUT
      printf '\nERROR: Docker failed.\n' >"$E"
      return $ERROR
    }

    [[ -z ${CC[skipmastersetup]} ]] && {
      run_with_progress \
        "    Setting up '${CC[clustername]}-master-$int'" \
        set_up_master_node "${CC[clustername]}-master-$int"
      r=$?

      [[ $r -ne 0 ]] && {
        printf '\n' >"$E"
        cat $RUNWITHPROGRESS_OUTPUT >"$E"
        printf '\nERROR: Set up failed. See above, and also in the file:' >"$E"
        printf '%s\n' "$RUNWITHPROGRESS_OUTPUT" >"$E"
        return $ERROR
      }
    }
  done

  # For now, copy admin.conf from master to ~/.mok/admin.conf

  masternum="${1##*-}" # <- eg. for xxx-master-1, masternum=1

  [[ -z ${CC[skipmastersetup]} && $masternum -eq 1 ]] && {
    mkdir -p ~/.mok/
    if [[ ${CC[withlb]} -eq $TRUE ]]; then
      lbaddr=$(CU_get_container_ip "${CC[clustername]}-lb")
      docker cp "${CC[clustername]}-master-1":/etc/kubernetes/admin.conf \
        /var/tmp/admin.conf || err || return
      sed -i 's#\(server: https://\)[0-9.]*\(:.*\)#\1'"$lbaddr"'\2#' /var/tmp/admin.conf
    else
      docker cp "${CC[clustername]}-master-1":/etc/kubernetes/admin.conf \
        /var/tmp/admin.conf || err || return
    fi
  }
  chmod 666 /var/tmp/admin.conf || {
    printf 'ERROR: Could not "chown 666 /var/tmp/admin.conf"'
    err || return
  }

  return $OK
}

# ---------------------------------------------------------------------------
set_up_master_node() {

  # Call the correct set up function based on the version
  # Args
  #   arg1 - the container ID to set up

  case "$BUILD_IMAGE_K8SVER" in
  "1.18.2")
    set_up_master_node_v1_18_2 "$@"
    ;;
  esac
}

# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------
create_worker_nodes() {

  # Create the master nodes
  # Args:
  #   arg1 - number of master nodes to create

  local cahash token t
  declare -i int=0

  [[ -n $CREATE_CLUSTER_SKIPWORKERSETUP || -n \
  ${CC[skipmastersetup]} ]] || {
    # Runs a script on master node to get details
    t=$(get_master_join_details "${CC[clustername]}-master-1") || {
      printf '\nERROR: Problem with "get_master_join_details".\n\n' >"$E"
      return $ERROR
    }

    # Sets cahash, token, and masterip:
    eval "$t"
  }

  for int in $(seq 1 "$1"); do
    run_with_progress \
      "    Creating worker container, '${CC[clustername]}-worker-$int'" \
      CU_create_container \
      "${CC[clustername]}-worker-${int}" \
      "$(CU_labelkey)=${CC[clustername]}" \
      "${CC[k8sver]}"
    r=$?

    [[ $r -ne 0 ]] && {
      printf '\n' >"$E"
      cat $RUNWITHPROGRESS_OUTPUT >"$E"
      rm $RUNWITHPROGRESS_OUTPUT >"$E"
      printf '\nERROR: Docker failed.\n' >"$E"
      return $ERROR
    }

    [[ -n $CREATE_CLUSTER_SKIPWORKERSETUP || -n \
    ${CC[skipmastersetup]} ]] || {
      run_with_progress \
        "    Setting up '${CC[clustername]}-worker-$int'" \
        set_up_worker_node "${CC[clustername]}-worker-$int" \
        "$cahash" "$token" "$masterip"
      r=$?

      [[ $r -ne 0 ]] && {
        printf '\n' >"$E"
        cat $RUNWITHPROGRESS_OUTPUT >"$E"
        printf '\nERROR: Set up failed. See above, and also in the file:\n' >"$E"
        printf '%s\n' "$RUNWITHPROGRESS_OUTPUT" >"$E"
        return $ERROR
      }
    }
  done

  return $OK
}

# ---------------------------------------------------------------------------
set_up_worker_node() {

  # Call the correct set up function based on the version
  # Args
  #   arg1 - the container ID to set up

  case "$BUILD_IMAGE_K8SVER" in
  "1.18.2")
    set_up_worker_node_v1_18_2 "$@"
    ;;
  esac
}

# ---------------------------------------------------------------------------
get_master_join_details() {

  # 'docker exec' into the master to get CA hash, a token, and the master IP.
  # The caller can eval the output of this function to set the variables:
  # cahash, token, and masterip.
  # Args:
  #   arg1 - id/name of master container

  local joinvarsfile master1ip

  joinvarsfile=$(mktemp -p /var/tmp) || {
    printf 'ERROR: mktmp failed.\n' >"$E"
    return $ERROR
  }

  master1ip=$(CU_get_container_ip "${CC[clustername]}-master-1") || err || return

  cat <<EnD >"$joinvarsfile"
#!/bin/bash
set -e

sed 's#\(server: https://\)[0-9.]*\(:.*\)#\1'"$master1ip"'\2#' \
  /etc/kubernetes/admin.conf >/etc/kubernetes/admin2.conf

cahash=\$(openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | \
        openssl rsa -pubin -outform der 2>/dev/null | \
        openssl dgst -sha256 -hex | sed 's/^.* //')
token=\$(kubeadm token create --kubeconfig=/etc/kubernetes/admin2.conf 2>/dev/null)
ip=\$(ip ro get 8.8.8.8 | cut -d" " -f 7)

printf 'cahash=%s\ntoken=%s\nmasterip=%s' "\$cahash" "\$token" "\$ip"

exit 0
EnD

  docker cp "$joinvarsfile" "$1":/root/joinvars.sh 2>$E || err || return
  rm -f "$joinvarsfile" 2>$E || err || return

  docker exec "$1" bash /root/joinvars.sh 2>$E || err
}

# ===========================================================================
# Funtions for installing specific vesions of kubernetes
# ===========================================================================

# ---------------------------------------------------------------------------
set_up_master_node_v1_18_2() {

  # Use kubeadm to set up the master node.
  # Args:
  #   arg1 - the container to set up.

  local setupfile lbaddr certSANs certkey masternum t
  # Set by get_master_join_details:
  local cahash token masterip

  setupfile=$(mktemp -p /var/tmp) || {
    printf 'ERROR: mktmp failed.\n' >"$E"
    return $ERROR
  }

  masternum="${1##*-}" # <- eg. for xxx-master-1, masternum=1

  if [[ ${CC[withlb]} == "$TRUE" && $masternum -eq 1 ]]; then

    # This is the first master node

    # Sets cahash, token, and masterip:
    lbaddr=$(CU_get_container_ip "${CC[clustername]}-lb")
    certSANs="certSANs: [ '$lbaddr' ]"
    uploadcerts="--upload-certs"
    certkey="CertificateKey: f8802e114ef118304e561c3acd4d0b543adc226b7a27f675f56564185ffe0c07"

  elif [[ ${CC[withlb]} == "$TRUE" && $masternum -ne 1 ]]; then

    # This is not the first master node, so join with the master
    # https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/high-availability/

    # Keep trying to get join details until apiserver is ready or we run out of tries
    for try in $(seq 1 9); do
      # Runs a script on master node to get join details
      t=$(get_master_join_details "${CC[clustername]}-master-1")
      retval=$?
      [[ $retval -eq 0 ]] && break
      [[ $try -eq 9 ]] && {
        printf '\nERROR: Problem with "get_master_join_details". Tried %d times\n\n' "$try" >"$E"
        return $ERROR
      }
      sleep 5
    done
    eval "$t"
  fi

  # Write the file
  cat <<EnD >"$setupfile"
# Disable ipv6
sysctl -w net.ipv6.conf.all.disable_ipv6=1
sysctl -w net.ipv6.conf.default.disable_ipv6=1

# CRIO version 1.18 needs storage changing to VFS
sed -i 's/\(^driver = \).*/\1"vfs"/' /etc/containers/storage.conf
systemctl restart crio

# Use a custom configuration. Default config created from kubeadm with:
#   kubeadm config print init-defaults
# then edited.

ipaddr=\$(ip ro get default 8.8.8.8 | head -n 1 | cut -f 7 -d " ")
podsubnet="10.244.0.0/16"
servicesubnet="10.96.0.0/16"

cat <<EOF >kubeadm-init-defaults.yaml
apiVersion: kubeadm.k8s.io/v1beta2
kind: InitConfiguration
$certkey
bootstrapTokens:
- groups:
  - system:bootstrappers:kubeadm:default-node-token
  token: abcdef.0123456789abcdef
  ttl: 24h0m0s
  usages:
  - signing
  - authentication
localAPIEndpoint:
  advertiseAddress: \$ipaddr
  bindPort: 6443
nodeRegistration:
  criSocket: /var/run/crio/crio.sock
  name: myk8s-master-1
  kubeletExtraArgs: {}
  taints:
  - effect: NoSchedule
    key: node-role.kubernetes.io/master
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
failSwapOn: false
featureGates:
  AllAlpha: false
  RunAsGroup: true
runtimeRequestTimeout: "5m"
---
kind: ClusterConfiguration
controlPlaneEndpoint: "${lbaddr:-\$ipaddr}:6443"
apiServer:
  timeoutForControlPlane: 4m0s
  $certSANs
apiVersion: kubeadm.k8s.io/v1beta2
certificatesDir: /etc/kubernetes/pki
clusterName: kubernetes
controllerManager: {}
dns:
  type: CoreDNS
etcd:
  local:
    dataDir: /var/lib/etcd
imageRepository: k8s.gcr.io
kubernetesVersion: v1.18.2
networking:
  dnsDomain: cluster.local
  podSubnet: \$podsubnet
  serviceSubnet: \$servicesubnet
scheduler: {}
EOF

if [[ -z "$masterip" ]]; then
  kubeadm init \\
    --ignore-preflight-errors Swap \\
    --config=kubeadm-init-defaults.yaml $uploadcerts

  export KUBECONFIG=/etc/kubernetes/admin.conf

  # Flannel - 10.244.0.0./16
  # Why isn't NETADMIN enough here? I think this is a CRI-O 'problem'
  curl -L https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml | sed 's/privileged: false/privileged: true/' | kubectl apply -f -

  # Weave - ?
  #kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=\$(kubectl version | base64 | tr -d '\n')"

  # Calico - custom 10.123.0.0/16
  # Calico is e2e tested by k8s team. Requires --pod-network-cidr=192.168.0.0/16
  #curl https://docs.projectcalico.org/v3.11/manifests/calico.yaml | sed 's#192.168.0.0/16#10.123.0.0/16#' | kubectl apply -f -
else
  kubeadm join $masterip:6443 \\
    --ignore-preflight-errors Swap \\
    --control-plane \\
    --token $token \\
    --discovery-token-ca-cert-hash sha256:$cahash \\
    --certificate-key f8802e114ef118304e561c3acd4d0b543adc226b7a27f675f56564185ffe0c07
fi

systemctl enable kubelet
EnD

  docker cp "$setupfile" "$1":/root/setup.sh || err || {
    rm -f "$setupfile"
    return $ERROR
  }

  # Run the file
  docker exec "$1" bash /root/setup.sh || err || return

  # Remove the taint if we're setting up a single node cluster

  [[ ${CC[numworkers]} -eq 0 ]] && {

    removetaint=$(mktemp -p /var/tmp) || {
      printf 'ERROR: mktmp failed.\n' >"$E"
      return $ERROR
    }

    # Write the file
    cat <<'EnD' >"$removetaint"
export KUBECONFIG=/etc/kubernetes/admin.conf
kubectl taint nodes --all node-role.kubernetes.io/master-
EnD

    docker cp "$removetaint" "$1":/root/removetaint.sh || err || {
      rm -f "$removetaint"
      return $ERROR
    }

    # Run the file
    docker exec "$1" bash /root/removetaint.sh || err
  }

  return "${OK}"
}

# ---------------------------------------------------------------------------
set_up_worker_node_v1_18_2() {

  # Use kubeadm to set up the master node
  # Args:
  #   arg1 - the container to set up.

  local setupfile cahash="$2" token="$3" masterip="$4"

  setupfile=$(mktemp -p /var/tmp) || {
    printf 'ERROR: mktmp failed.\n' >"$E"
    return $ERROR
  }

  if [[ ${CC[withlb]} == "${TRUE}" ]]; then
    masterip=$(CU_get_container_ip "${CC[clustername]}-lb") || return
  fi

  cat <<EnD >"$setupfile"
# CRIO version 1.18 needs storage changing to VFS
sed -i 's/\(^driver = \).*/\1"vfs"/' /etc/containers/storage.conf
systemctl restart crio

# Wait for the master API to become ready
while true; do
  curl -k https://$masterip:6443/
  [[ \$? -eq 0 ]] && break
  sleep 1
done

# Do the preflight tests (ignoring swap error)
kubeadm join \\
  phase preflight \\
    --token $token \\
    --discovery-token-ca-cert-hash sha256:$cahash \\
    --ignore-preflight-errors Swap \\
    $masterip:6443

# Set up the kubelet
kubeadm join \\
  phase kubelet-start \\
    --token $token \\
    --discovery-token-ca-cert-hash sha256:$cahash \\
    $masterip:6443 &

while true; do
  [[ -e /var/lib/kubelet/config.yaml ]] && break
    sleep 1
  done

# Edit the kubelet configuration file
echo "failSwapOn: false" >>/var/lib/kubelet/config.yaml

systemctl enable --now kubelet
EnD

  docker cp "$setupfile" "$1":/root/setup.sh 2>$E || err || {
    rm -f "$setupfile"
    return $ERROR
  }

  docker exec "$1" bash /root/setup.sh || err
}

# ---------------------------------------------------------------------------

# Calls main() if we're called from the command line
if [ "$0" = "${BASH_SOURCE[0]}" ] || [ -z "${BASH_SOURCE[0]}" ]; then
  main "$@"
fi

# vim helpers -----------------------------------------------------------------
#include globals.sh
# vim:ft=sh:sw=2:et:ts=2:
