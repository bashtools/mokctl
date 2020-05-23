# GLOBALS
# Don't change any globals

# ---------------------------------------------------------------------------
create_usage() {

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

# ---------------------------------------------------------------------------
do_create() {

  # Calls the correct command/subcommand function

  case $SUBCOMMAND in
  cluster)
    do_create_cluster_sanity_checks || return
    do_create_cluster_mutate
    ;;
  esac
}

# ---------------------------------------------------------------------------
do_create_cluster_sanity_checks() {

  # Creates a mok cluster. All user vars have been parsed and saved.
  # Globals: CREATE_CLUSTER_NAME CREATE_CLUSTER_NUM_MASTERS
  #          CREATE_CLUSTER_NUM_WORKERS
  # No args expected

  if [[ -z $CREATE_CLUSTER_NAME ]]; then
    usage
    printf 'Please provide the Cluster NAME to create.\n' >"$E"
    return $ERROR
  fi

  if [[ -z $CREATE_CLUSTER_NUM_MASTERS || $CREATE_CLUSTER_NUM_MASTERS -le 0 ]]; then
    usage
    printf 'Please provide the number of Masters to create. Must be 1 or more.\n' >"$E"
    return $ERROR
  fi

  if [[ -z $CREATE_CLUSTER_NUM_WORKERS ]]; then
    usage
    printf 'Please provide the number of Workers to create.\n' >"$E"
    return $ERROR
  fi
}

# ===========================================================================
#                                MUTATIONS
#                FUNCTIONS IN THIS SECTION CHANGE SYSTEM STATE
# ===========================================================================

# ---------------------------------------------------------------------------
do_create_cluster_mutate() {

  # Mutate functions make system changes.
  # Global variables:
  #   CREATE_CLUSTER_NAME        - (string) cluster name
  #   CREATE_CLUSTER_NUM_MASTERS - (int) num masters
  #   CREATE_CLUSTER_NUM_WORKERS - (int) num workers

  declare -i numnodes=0

  numnodes=$(get_cluster_size $CREATE_CLUSTER_NAME) || return

  [[ $numnodes -gt 0 ]] && {
    printf '\nERROR: Cluster, "%s", exists! Aborting.\n\n' "$CREATE_CLUSTER_NAME" >"$E"
    return $ERROR
  }

  printf '\n'

  [[ $CREATE_CLUSTER_WITH_LB -gt 0 ]] && {
    create_lb_node $CREATE_CLUSTER_NUM_MASTERS || return
  }

  [[ $CREATE_CLUSTER_NUM_MASTERS -gt 0 ]] && {
    create_master_nodes $CREATE_CLUSTER_NUM_MASTERS || return
  }

  #[[ -z $CREATE_CLUSTER_SKIPMASTERSETUP ]] && {
  #  # TODO Query the server for all pods ready instead
  #  run_with_progress \
  #    "    Waiting for master to be ready." \
  #    sleep 40
  #}

  [[ $CREATE_CLUSTER_WITH_LB -gt 0 ]] && {
    setup_lb_node $CREATE_CLUSTER_NUM_MASTERS || return
  }

  [[ $CREATE_CLUSTER_NUM_WORKERS -gt 0 ]] && {
    create_worker_nodes "$CREATE_CLUSTER_NUM_WORKERS" || return
  }

  printf '\n'

  [[ -z $CREATE_CLUSTER_SKIPMASTERSETUP ]] && {
    printf 'Cluster, "%s", can be accessed using:\n\n' "$CREATE_CLUSTER_NAME"
    printf 'export KUBECONFIG=/var/tmp/admin.conf\n\n'
  }

  return $OK
}

# ---------------------------------------------------------------------------
get_cluster_size() {

  # Search for an existing cluster using labels. All cluster nodes are
  # labelled with $LABELKEY=$CREATE_CLUSTER_NAME
  # Args:
  #   arg1 - name to search for.

  local output
  declare -a nodes

  output=$(get_docker_ids_for_cluster "$1") || err || return

  # readarray will read null as an array item so don't run
  # through readarray if it's null
  [[ -z $output ]] && {
    printf '0'
    return $OK
  }

  # read the nodes array and delete blank lines
  readarray -t nodes <<<"$output"

  printf '%d' "${#nodes[*]}"
}

# ---------------------------------------------------------------------------
get_docker_ids_for_cluster() {

  # Get all cluster ids for labelled containers
  # Args:
  #   arg1 - Cluster name

  local value output

  [[ -n $1 ]] && value="=$1"

  output=$(docker ps -a -f label="$LABELKEY$value" -q) || {
    printf 'ERROR: Docker command failed\n\n' >"$E"
    err || return
  }

  output=$(printf '%s' "$output" | sed 's/$//')

  printf '%s' "$output"

  return $OK
}

# ---------------------------------------------------------------------------
create_lb_node() {

  # Create the load balancer nodes
  # Args:

  # Ceate container
  run_with_progress \
    "    Creating load balancer container, '$CREATE_CLUSTER_NAME-lb'" \
    create_docker_container \
    "$CREATE_CLUSTER_NAME-lb" \
    "$LABELKEY=$CREATE_CLUSTER_NAME"

  [[ $r -ne 0 ]] && {
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
      "    Setting up '$CREATE_CLUSTER_NAME-lb'" \
      set_up_lb_node_real "$CREATE_CLUSTER_NAME-lb"
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
  for idx in $(seq 1 $CREATE_CLUSTER_NUM_MASTERS); do
    ip=$(get_docker_container_ip "$CREATE_CLUSTER_NAME-master-$idx")
    masteriplist="$masteriplist$nl    server master-$idx $ip:6443 check fall 3 rise 2"
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
      "    Creating master container, '$CREATE_CLUSTER_NAME-master-$int'" \
      create_docker_container \
      "$CREATE_CLUSTER_NAME-master-$int" \
      "$LABELKEY=$CREATE_CLUSTER_NAME"
    r=$?

    [[ $r -ne 0 ]] && {
      printf '\n'
      cat $RUNWITHPROGRESS_OUTPUT >"$E"
      rm $RUNWITHPROGRESS_OUTPUT
      printf '\nERROR: Docker failed.\n' >"$E"
      return $ERROR
    }

    [[ -z $CREATE_CLUSTER_SKIPMASTERSETUP ]] && {
      run_with_progress \
        "    Setting up '$CREATE_CLUSTER_NAME-master-$int'" \
        set_up_master_node "$CREATE_CLUSTER_NAME-master-$int"
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

  [[ -z $CREATE_CLUSTER_SKIPMASTERSETUP && $masternum -eq 1 ]] && {
    mkdir -p ~/.mok/
    if [[ $CREATE_CLUSTER_WITH_LB -eq $TRUE ]]; then
      lbaddr=$(get_docker_container_ip "$CREATE_CLUSTER_NAME-lb")
      docker cp "$CREATE_CLUSTER_NAME-master-1":/etc/kubernetes/admin.conf \
        /var/tmp/admin.conf || err || return
      sed -i 's#\(server: https://\)[0-9.]*\(:.*\)#\1'"$lbaddr"'\2#' /var/tmp/admin.conf
    else
      docker cp "$CREATE_CLUSTER_NAME-master-1":/etc/kubernetes/admin.conf \
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
create_docker_container() {

  # Runs a new container with docker run.
  # Args:
  #   arg1 - name to use as the name and hostname.
  #   arg2 - the label to write to the container.

  local imglocal="${PODMANIMGPREFIX}local/$BASEIMAGENAME-v$CREATE_CLUSTER_K8SVER"
  local imgremote="docker.io/mclarkson/$BASEIMAGENAME-v$CREATE_CLUSTER_K8SVER"
  local allimgs

  # Prefer a locally built container over one downloaded from a registry
  allimgs=$(podman images -n)
  if echo "$allimgs" | grep -qs "$imglocal"; then
    imagename="$imglocal"
  elif echo "$allimgs" | grep -qs "$imgremote"; then
    imagename="$imgremote"
  else
    cat <<EnD
ERROR: No container base image found. Use either:

  $ mokctl build image
OR
  $ mokctl build image --get-prebuilt-image

Then try running 'mokctl create ...' again.
EnD
  fi

  docker run --privileged \
    -v /sys/fs/cgroup:/sys/fs/cgroup:ro \
    -v /lib/modules:/lib/modules:ro \
    --tmpfs /run --tmpfs /tmp \
    --detach \
    --name "$1" \
    --hostname "$1" \
    --label "$2" \
    "$imagename"
}

# ---------------------------------------------------------------------------
create_worker_nodes() {

  # Create the master nodes
  # Args:
  #   arg1 - number of master nodes to create

  local cahash token t
  declare -i int=0

  [[ -n $CREATE_CLUSTER_SKIPWORKERSETUP || -n \
  $CREATE_CLUSTER_SKIPMASTERSETUP ]] || {
    # Runs a script on master node to get details
    t=$(get_master_join_details $CREATE_CLUSTER_NAME-master-1) || {
      printf '\nERROR: Problem with "get_master_join_details".\n\n' >"$E"
      return $ERROR
    }

    # Sets cahash, token, and masterip:
    eval "$t"
  }

  for int in $(seq 1 "$1"); do
    run_with_progress \
      "    Creating worker container, '$CREATE_CLUSTER_NAME-worker-$int'" \
      create_docker_container \
      "$CREATE_CLUSTER_NAME-worker-$int" \
      "$LABELKEY=$CREATE_CLUSTER_NAME"
    r=$?

    [[ $r -ne 0 ]] && {
      printf '\n' >"$E"
      cat $RUNWITHPROGRESS_OUTPUT >"$E"
      rm $RUNWITHPROGRESS_OUTPUT >"$E"
      printf '\nERROR: Docker failed.\n' >"$E"
      return $ERROR
    }

    [[ -n $CREATE_CLUSTER_SKIPWORKERSETUP || -n \
    $CREATE_CLUSTER_SKIPMASTERSETUP ]] || {
      run_with_progress \
        "    Setting up '$CREATE_CLUSTER_NAME-worker-$int'" \
        set_up_worker_node "$CREATE_CLUSTER_NAME-worker-$int" \
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

  master1ip=$(get_docker_container_ip "$CREATE_CLUSTER_NAME-master-1") || err || return

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

  if [[ $CREATE_CLUSTER_WITH_LB == "$TRUE" && $masternum -eq 1 ]]; then

    # This is the first master node

    # Sets cahash, token, and masterip:
    lbaddr=$(get_docker_container_ip "$CREATE_CLUSTER_NAME-lb")
    certSANs="certSANs: [ '$lbaddr' ]"
    uploadcerts="--upload-certs"
    certkey="CertificateKey: f8802e114ef118304e561c3acd4d0b543adc226b7a27f675f56564185ffe0c07"

  elif [[ $CREATE_CLUSTER_WITH_LB == "$TRUE" && $masternum -ne 1 ]]; then

    # This is not the first master node, so join with the master
    # https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/high-availability/

    # Keep trying to get join details until apiserver is ready or we run out of tries
    for try in $(seq 1 9); do
      # Runs a script on master node to get join details
      t=$(get_master_join_details "$CREATE_CLUSTER_NAME-master-1")
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

  [[ $CREATE_CLUSTER_NUM_WORKERS -eq 0 ]] && {

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

  return $OK
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

  if [[ $CREATE_CLUSTER_WITH_LB == "$TRUE" ]]; then
    masterip=$(get_docker_container_ip "$CREATE_CLUSTER_NAME-lb")
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
