# KTHW 09 Bootstrapping Kubernetes Workers

![](../docs/images/kthw-9.gif)

View the [screencast file](../cmdline-player/kthw-9.scr)

```bash
# ---------------------------------------------------------
# Kubernetes the Hard Way - using `mokctl` from My Own Kind
# ---------------------------------------------------------
# 09-bootstrapping-kubernetes-workers
# Configure and start the kubernetes workers

# Provision the Kubernetes Worker Nodes

# We will use 'tmux' to log in to three containers and then
# execute the commands in parallel.

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
# syncing screens
^a^x
# Panes are now synced!
# Clearing the screen
clear
# Remove the existing k8s services:
yum -y remove kubelet kubeadm cri-o cri-tools runc criu
cd # <- All our certs are in root's home
# Install OS dependencies
{
  yum -y install socat conntrack ipset wget
}
# Is swap on?
swapon --show
# Yes, and so it should be for a laptop.
# `mokctl` uses a kubeadm configuration file to get components to ignore swap.
# For this lab the following lines will trick kubernetes into
# thinking that swap is off instead:
touch /swapoff
mount --bind /swapoff /proc/swaps
# We don't want to turn swap off on our laptop.
# Is swap on?
swapon --show
# Seems to be off now :)
# Download the worker binaries
wget https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.15.0/crictl-v1.15.0-linux-amd64.tar.gz \
  https://github.com/opencontainers/runc/releases/download/v1.0.0-rc8/runc.amd64 \
  https://github.com/containernetworking/plugins/releases/download/v0.8.2/cni-plugins-linux-amd64-v0.8.2.tgz \
  https://github.com/containerd/containerd/releases/download/v1.2.9/containerd-1.2.9.linux-amd64.tar.gz \
  https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/linux/amd64/kubectl \
  https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/linux/amd64/kube-proxy \
  https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/linux/amd64/kubelet
# Create the installation directories:
mkdir -p \
  /etc/cni/net.d \
  /opt/cni/bin \
  /var/lib/kubelet \
  /var/lib/kube-proxy \
  /var/lib/kubernetes \
  /var/run/kubernetes
# Install the worker binaries:
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
# Work out the pod subnet for this host:
POD_CIDR="10.200.$(hostname -s | grep -o '.$').0/24"
echo $POD_CIDR
# Write the CNI bridge configuration:
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
# Write the CNI loopback device config:
cat <<EOF | tee /etc/cni/net.d/99-loopback.conf
{
    "cniVersion": "0.3.1",
    "name": "lo",
    "type": "loopback"
}
EOF
# Containerd config:
mkdir -p /etc/containerd/
containerd config default | sed 's/overlayfs/native/' >/etc/containerd/config.toml
# Create the systemd unit file:
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
# Configure the kubelet:
{
  mv ${HOSTNAME}-key.pem ${HOSTNAME}.pem /var/lib/kubelet/
  mv ${HOSTNAME}.kubeconfig /var/lib/kubelet/kubeconfig
  mv ca.pem /var/lib/kubernetes/
}
# Kubelet config:
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
# Create systemd unit file for kubelet:
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
# Configure the kube-proxy:
mv kube-proxy.kubeconfig /var/lib/kube-proxy/kubeconfig
# Write the kube-proxy-config.yaml file:
cat <<EOF | tee /var/lib/kube-proxy/kube-proxy-config.yaml
kind: KubeProxyConfiguration
apiVersion: kubeproxy.config.k8s.io/v1alpha1
clientConnection:
  kubeconfig: "/var/lib/kube-proxy/kubeconfig"
mode: "iptables"
clusterCIDR: "10.200.0.0/16"
EOF
# Write the systemd unit file for kube-proxy:
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
# Start worker services:
{
  systemctl daemon-reload
  systemctl enable containerd kubelet kube-proxy
  systemctl start containerd kubelet kube-proxy
}
# Log out of the workers:
exit
exit
# And log in to kthw-master-1
sudo mokctl exec kthw-master-1
cd    # <- our admin.kubeconfig is in root's home (/root)
# Verification - list the nodes:
kubectl get nodes --kubeconfig admin.kubeconfig
# It worked!
# Log out of the master container
exit
# All done :)

# -------------------------------------------
# Next: Configuring kubectl for Remote Access
# -------------------------------------------
```
