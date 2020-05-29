# CC - Create Cluster - versions file

# CC is an associative array that holds data specific to creating a cluster.
declare -A _CC

# Declare externally defined variables ----------------------------------------

# Defined in GL (globals.sh)
declare OK ERROR STDERR TRUE

# _CC_set_up_master_node_v1_18_2 sets up a master node of a kubernetes 1.18.2
# cluster.
_CC_set_up_master_node_v1_18_2() {
  _CC_set_up_master_node_v1_18_3 "$@"
}

# _CC_set_up_worker_node_v1_18_3 uses kubeadm to set up the master node.
# Args: arg1 - the container to set up.
_CC_set_up_master_node_v1_18_3() {

  local setupfile lbaddr certSANs certkey masternum t
  # Set by _CC_get_master_join_details:
  local cahash token masterip

  setupfile=$(mktemp -p /var/tmp) || {
    printf 'ERROR: mktmp failed.\n' >"${STDERR}"
    return "${ERROR}"
  }

  masternum="${1##*-}" # <- eg. for xxx-master-1, masternum=1

  if [[ ${_CC[withlb]} == "${TRUE}" && ${masternum} -eq 1 ]]; then

    # This is the first master node

    # Sets cahash, token, and masterip:
    lbaddr=$(CU_get_container_ip "${_CC[clustername]}-lb")
    certSANs="certSANs: [ '${lbaddr}' ]"
    uploadcerts="--upload-certs"
    certkey="CertificateKey: f8802e114ef118304e561c3acd4d0b543adc226b7a27f675f56564185ffe0c07"

  elif [[ ${_CC[withlb]} == "${TRUE}" && ${masternum} -ne 1 ]]; then

    # This is not the first master node, so join with the master
    # https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/high-availability/

    # Keep trying to get join details until apiserver is ready or we run out of tries
    for try in $(seq 1 9); do
      # Runs a script on master node to get join details
      t=$(_CC_get_master_join_details "${_CC[clustername]}-master-1")
      retval=$?
      [[ ${retval} -eq 0 ]] && break
      [[ ${try} -eq 9 ]] && {
        printf '\nERROR: Problem with "_CC_get_master_join_details". Tried %d times\n\n' "${try}" \
          >"${STDERR}"
        return "${ERROR}"
      }
      sleep 5
    done
    eval "${t}"
  fi

  # Write the file
  cat <<EnD >"${setupfile}"
# Disable ipv6
sysctl -w net.ipv6.conf.all.disable_ipv6=1
sysctl -w net.ipv6.conf.default.disable_ipv6=1

# Use a custom configuration. Default config created from kubeadm with:
#   kubeadm config print init-defaults
# then edited.

ipaddr=\$(ip ro get default 8.8.8.8 | head -n 1 | cut -f 7 -d " ")
podsubnet="10.244.0.0/16"
servicesubnet="10.96.0.0/16"

cat <<EOF >kubeadm-init-defaults.yaml
apiVersion: kubeadm.k8s.io/v1beta2
kind: InitConfiguration
${certkey}
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
  ${certSANs}
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
kubernetesVersion: v1.18.3
networking:
  dnsDomain: cluster.local
  podSubnet: \$podsubnet
  serviceSubnet: \$servicesubnet
scheduler: {}
EOF

if [[ -z "${masterip}" ]]; then
  kubeadm init \\
    --ignore-preflight-errors Swap \\
    --config=kubeadm-init-defaults.yaml ${uploadcerts}

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
  kubeadm join ${masterip}:6443 \\
    --ignore-preflight-errors Swap \\
    --control-plane \\
    --token ${token} \\
    --discovery-token-ca-cert-hash sha256:${cahash} \\
    --certificate-key f8802e114ef118304e561c3acd4d0b543adc226b7a27f675f56564185ffe0c07
fi

systemctl enable kubelet
EnD

  docker cp "${setupfile}" "$1":/root/setup.sh || err || {
    rm -f "${setupfile}"
    return "${ERROR}"
  }

  # Run the file
  docker exec "$1" bash /root/setup.sh || err || return

  # Remove the taint if we're setting up a single node cluster

  [[ ${_CC[numworkers]} -eq 0 ]] && {

    removetaint=$(mktemp -p /var/tmp) || {
      printf 'ERROR: mktmp failed.\n' >"${STDERR}"
      return "${ERROR}"
    }

    # Write the file
    cat <<'EnD' >"${removetaint}"
export KUBECONFIG=/etc/kubernetes/admin.conf
kubectl taint nodes --all node-role.kubernetes.io/master-
EnD

    docker cp "${removetaint}" "$1":/root/removetaint.sh || err || {
      rm -f "${removetaint}"
      return "${ERROR}"
    }

    # Run the file
    docker exec "$1" bash /root/removetaint.sh || err
  }

  return "${OK}"
}

# _CC_set_up_worker_node_v1_18_2 sets up a worker node of a kubernetes 1.18.2
# cluster.
_CC_set_up_worker_node_v1_18_2() {
  _CC_set_up_worker_node_v1_18_3 "$@"
}

# _CC_set_up_worker_node_v1_18_3 uses kubeadm to set up the worker node.
# Args: arg1 - the container to set up.
_CC_set_up_worker_node_v1_18_3() {

  local setupfile cahash="$2" token="$3" masterip="$4"

  setupfile=$(mktemp -p /var/tmp) || {
    printf 'ERROR: mktmp failed.\n' >"${STDERR}"
    return "${ERROR}"
  }

  if [[ ${_CC[withlb]} == "${TRUE}" ]]; then
    masterip=$(CU_get_container_ip "${_CC[clustername]}-lb") || return
  fi

  cat <<EnD >"${setupfile}"
# CRIO version 1.18 needs storage changing to VFS
sed -i 's/\(^driver = \).*/\1"vfs"/' /etc/containers/storage.conf
systemctl restart crio

# Wait for the master API to become ready
while true; do
  curl -k https://${masterip}:6443/
  [[ \$? -eq 0 ]] && break
  sleep 1
done

# Do the preflight tests (ignoring swap error)
kubeadm join \\
  phase preflight \\
    --token ${token} \\
    --discovery-token-ca-cert-hash sha256:${cahash} \\
    --ignore-preflight-errors Swap \\
    ${masterip}:6443

# Set up the kubelet
kubeadm join \\
  phase kubelet-start \\
    --token ${token} \\
    --discovery-token-ca-cert-hash sha256:${cahash} \\
    ${masterip}:6443 &

while true; do
  [[ -e /var/lib/kubelet/config.yaml ]] && break
    sleep 1
  done

# Edit the kubelet configuration file
echo "failSwapOn: false" >>/var/lib/kubelet/config.yaml

systemctl enable --now kubelet
EnD

  docker cp "${setupfile}" "$1":/root/setup.sh 2>"${STDERR}" || err || {
    rm -f "${setupfile}"
    return "${ERROR}"
  }

  docker exec "$1" bash /root/setup.sh || err
}
