>  **Kubernetes the Hard Way using My Own Kind**
> 
> View a [screencast and transcript](/cmdline-player/kthw-9.md)
# Bootstrapping the Kubernetes Worker Nodes

In this lab you will bootstrap three Kubernetes worker nodes. The following components will be installed on each node: [runc](https://github.com/opencontainers/runc), [container networking plugins](https://github.com/containernetworking/cni), [containerd](https://github.com/containerd/containerd), [kubelet](https://kubernetes.io/docs/admin/kubelet), and [kube-proxy](https://kubernetes.io/docs/concepts/cluster-administration/proxies).

## Prerequisites

The commands in this lab must be run on each worker instance: `kthw-worker-1`, `kthw-worker-2`, and `kthw-worker-3`. Log in to each controller instance using the `mokctl` command. Example:

```
mokctl exec kthw-worker-1
```

### Running commands in parallel with tmux

[tmux](https://github.com/tmux/tmux/wiki) can be used to run commands on multiple compute instances at the same time. See the [Running commands in parallel with tmux](01-prerequisites.md#running-commands-in-parallel-with-tmux) section in the Prerequisites lab.

## Provisioning a Kubernetes Worker Node

Use `tmux` to log in to all three worker at the same time:

```
tmux
tmux set status off
tmux split
tmux split
tmux select-layout even-vertical
tmux select-pane -D
sudo mokctl exec kthw-worker-1
^aj
sudo mokctl exec kthw-worker-2
^aj
tmux select-layout tiled
tmux resize-pane -y 25
sudo mokctl exec kthw-worker-3
^a^x
clear
```

`mokctl` installed a few kubernetes services ready for set up.

Ensure all existing kubernetes services are deleted:

```
yum -y remove kubelet kubeadm cri-o cri-tools runc criu
```

Change to root's home directory, where the certs are:

```
cd # <- All our certs are in root's home
```

Install the OS dependencies:

```
{
  yum -y install socat conntrack ipset wget
}
```

> The socat binary enables support for the `kubectl port-forward` command.

### Disable Swap

By default the kubelet will fail to start if [swap](https://help.ubuntu.com/community/SwapFaq) is enabled. It is [recommended](https://github.com/kubernetes/kubernetes/issues/7294) that swap be disabled to ensure Kubernetes can provide proper resource allocation and quality of service.

Verify if swap is enabled:

```
swapon --show
```

If output is empty then swap is not enabled. If swap is enabled run the following command to disable swap immediately:

```
touch /swapoff
mount --bind /swapoff /proc/swaps
```

Verify again if swap is enabled:

```
swapon --show
```

Swap should now return no output, meaning, it's off.

> Swap is not actually turned off, since you don't want to do that on your laptop.

### Configure the `/etc/hosts` file

We need to add name-to-IP DNS resolution for the 'nodes' in the cluster. Adding the mappings to the `/etc/hosts` file is a simple way to do this. Another way would be to add DNS entries to a DNS server on your local network.

Set some variables to hold the masters IP addresses:

```
MASTER1=$(grep kthw-master-1 /root/cluster-list.txt | awk '{ print $NF; }')
echo $MASTER1
MASTER2=$(grep kthw-master-2 /root/cluster-list.txt | awk '{ print $NF; }')
echo $MASTER2
MASTER3=$(grep kthw-master-3 /root/cluster-list.txt | awk '{ print $NF; }')
echo $MASTER3
```

Set some variables to hold the workers IP addresses:

```
WORKER1=$(grep kthw-worker-1 /root/cluster-list.txt | awk '{ print $NF; }')
echo $WORKER1
WORKER2=$(grep kthw-worker-2 /root/cluster-list.txt | awk '{ print $NF; }')
echo $WORKER2
WORKER3=$(grep kthw-worker-3 /root/cluster-list.txt | awk '{ print $NF; }')
echo $WORKER3
```

Add names to `/etc/hosts`:

```
{
cat <<EnD | tee -a /etc/hosts
$MASTER1 kthw-master-1
$MASTER2 kthw-master-2
$MASTER3 kthw-master-3
$WORKER1 kthw-worker-1
$WORKER2 kthw-worker-2
$WORKER3 kthw-worker-3
EnD
}
```

### Download and Install Worker Binaries

```
wget https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.15.0/crictl-v1.15.0-linux-amd64.tar.gz \
  https://github.com/opencontainers/runc/releases/download/v1.0.0-rc8/runc.amd64 \
  https://github.com/containernetworking/plugins/releases/download/v0.8.2/cni-plugins-linux-amd64-v0.8.2.tgz \
  https://github.com/containerd/containerd/releases/download/v1.2.9/containerd-1.2.9.linux-amd64.tar.gz \
  https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/linux/amd64/kubectl \
  https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/linux/amd64/kube-proxy \
  https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/linux/amd64/kubelet
```

Create the installation directories:

```
mkdir -p \
  /etc/cni/net.d \
  /opt/cni/bin \
  /var/lib/kubelet \
  /var/lib/kube-proxy \
  /var/lib/kubernetes \
  /var/run/kubernetes
```

Install the worker binaries:

```
{
  mkdir containerd
  tar -xvf crictl-v1.15.0-linux-amd64.tar.gz
  tar -xvf containerd-1.2.9.linux-amd64.tar.gz -C containerd
  tar -xvf cni-plugins-linux-amd64-v0.8.2.tgz -C /opt/cni/bin/
  mv runc.amd64 runc
  chmod +x crictl kubectl kube-proxy kubelet runc 
  mv -f crictl kubectl kube-proxy kubelet runc /usr/local/bin/
  mv -f containerd/bin/* /bin/
}
```

### Configure CNI Networking

Work out the Pod CIDR range for the current compute instance.

We will use the following subnets from the 10.200.0.0/16 range:

*  10.200.1.0/24 for kthw-worker-1
*  10.200.2.0/24 for kthw-worker-2
*  10.200.3.0/24 for kthw-worker-3

```
POD_CIDR="10.200.$(hostname -s | grep -o '.$').0/24"
echo $POD_CIDR
```

Create the `bridge` network configuration file:

```
cat <<EOF | tee /etc/cni/net.d/10-bridge.conf
{
    "cniVersion": "0.3.1",
    "name": "bridge",
    "type": "bridge",
    "bridge": "cnio0",
    "isGateway": true,
    "ipMasq": true,
    "ipam": {
        "type": "host-local",
        "ranges": [
          [{"subnet": "${POD_CIDR}"}]
        ],
        "routes": [{"dst": "0.0.0.0/0"}]
    }
}
EOF
```

Create the `loopback` network configuration file:

```
cat <<EOF | tee /etc/cni/net.d/99-loopback.conf
{
    "cniVersion": "0.3.1",
    "name": "lo",
    "type": "loopback"
}
EOF
```

### Configure containerd

See also: [Docker Storage Drivers](https://docs.docker.com/storage/storagedriver/select-storage-driver/).

Create the `containerd` configuration file:

```
mkdir -p /etc/containerd/
```

Write a default configuration using the 'native' storage driver:

```
containerd config default | sed 's/overlayfs/native/' >/etc/containerd/config.toml
```

Create the `containerd.service` systemd unit file:

```
cat <<EOF | tee /etc/systemd/system/containerd.service
[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target
[Service]
ExecStartPre=/sbin/modprobe overlay
ExecStart=/bin/containerd
Restart=always
RestartSec=5
Delegate=yes
KillMode=process
OOMScoreAdjust=-999
LimitNOFILE=1048576
LimitNPROC=infinity
LimitCORE=infinity
[Install]
WantedBy=multi-user.target
EOF
```

### Configure the Kubelet

```
{
  mv ${HOSTNAME}-key.pem ${HOSTNAME}.pem /var/lib/kubelet/
  mv ${HOSTNAME}.kubeconfig /var/lib/kubelet/kubeconfig
  mv ca.pem /var/lib/kubernetes/
}
```

Create the `kubelet-config.yaml` configuration file:

```
cat <<EOF | tee /var/lib/kubelet/kubelet-config.yaml
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
  x509:
    clientCAFile: "/var/lib/kubernetes/ca.pem"
authorization:
  mode: Webhook
clusterDomain: "cluster.local"
clusterDNS:
  - "10.32.0.10"
podCIDR: "${POD_CIDR}"
runtimeRequestTimeout: "15m"
tlsCertFile: "/var/lib/kubelet/${HOSTNAME}.pem"
tlsPrivateKeyFile: "/var/lib/kubelet/${HOSTNAME}-key.pem"
EOF
```

> The `resolvConf` configuration is used to avoid loops when using CoreDNS for service discovery on systems running `systemd-resolved`. 

Create the `kubelet.service` systemd unit file:

```
cat <<EOF | tee /etc/systemd/system/kubelet.service
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/kubernetes/kubernetes
After=containerd.service
Requires=containerd.service
[Service]
ExecStart=/usr/local/bin/kubelet \\
  --config=/var/lib/kubelet/kubelet-config.yaml \\
  --container-runtime=remote \\
  --container-runtime-endpoint=unix:///var/run/containerd/containerd.sock \\
  --image-pull-progress-deadline=2m \\
  --kubeconfig=/var/lib/kubelet/kubeconfig \\
  --network-plugin=cni \\
  --register-node=true \\
  --v=2
Restart=on-failure
RestartSec=5
[Install]
WantedBy=multi-user.target
EOF
```

### Configure the Kubernetes Proxy

```
mv kube-proxy.kubeconfig /var/lib/kube-proxy/kubeconfig
```

Create the `kube-proxy-config.yaml` configuration file:

```
cat <<EOF | tee /var/lib/kube-proxy/kube-proxy-config.yaml
kind: KubeProxyConfiguration
apiVersion: kubeproxy.config.k8s.io/v1alpha1
clientConnection:
  kubeconfig: "/var/lib/kube-proxy/kubeconfig"
mode: "iptables"
clusterCIDR: "10.200.0.0/16"
EOF
```

Create the `kube-proxy.service` systemd unit file:

```
cat <<EOF | tee /etc/systemd/system/kube-proxy.service
[Unit]
Description=Kubernetes Kube Proxy
Documentation=https://github.com/kubernetes/kubernetes
[Service]
ExecStart=/usr/local/bin/kube-proxy \\
  --config=/var/lib/kube-proxy/kube-proxy-config.yaml
Restart=on-failure
RestartSec=5
[Install]
WantedBy=multi-user.target
EOF
```

### Start the Worker Services

```
{
  systemctl daemon-reload
  systemctl enable containerd kubelet kube-proxy
  systemctl start containerd kubelet kube-proxy
}
```

> Remember to run the above commands on each worker node: `kthw-worker-1`, `kthw-worker-2`, and `kthw-worker-3`.

## Verification

> The compute instances created in this tutorial will not have permission to complete this section. Run the following commands from one of the master nodes.

Log out of the workers:

```
exit
exit
```

Log in to one of the master nodes to run kubectl:

```
sudo mokctl exec kthw-master-1
cd    # <- our admin.kubeconfig is in root's home (/root)
```

List the registered Kubernetes nodes:

```
kubectl get nodes --kubeconfig admin.kubeconfig
```

> output

```
NAME            STATUS   ROLES    AGE   VERSION
kthw-worker-1   Ready    <none>   15s   v1.15.3
kthw-worker-2   Ready    <none>   15s   v1.15.3
kthw-worker-3   Ready    <none>   15s   v1.15.3
```

Log out of the master container:

```
exit
```


Next: [Configuring kubectl for Remote Access](10-configuring-kubectl.md)
