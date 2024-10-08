# Notes

Getting mokctl up and running with kubernetes v1.29 and cri-o v1.29

```
podman build --env GO_VERSION=1.23.2 -t debian-systemd .

# -v /sys/fs/cgroup:/sys/fs/cgroup:ro #<-- don't need
podman run -d --systemd=always --name debian-systemd \
  --privileged -v /lib/modules:/lib/modules debian-systemd

podman exec -ti debian-systemd bash
```

# Install kubernetes

```
apt-get update && \
apt-get install -y apt-transport-https ca-certificates curl gpg socat

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list
apt-get update
apt-get install -y kubectl kubeadm kubelet

systemctl enable --now kubelet

# Install cri-o
KUBERNETES_VERSION=v1.29
CRIO_VERSION=v1.29
apt-get update
apt-get install -y software-properties-common curl
curl -fsSL https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/deb/Release.key |
    gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/deb/ /" |
    tee /etc/apt/sources.list.d/kubernetes.list

curl -fsSL https://pkgs.k8s.io/addons:/cri-o:/stable:/$CRIO_VERSION/deb/Release.key |
    gpg --dearmor -o /etc/apt/keyrings/cri-o-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] https://pkgs.k8s.io/addons:/cri-o:/stable:/$CRIO_VERSION/deb/ /" |
    tee /etc/apt/sources.list.d/cri-o.list

apt-get update && \
apt-get install -y cri-o kubelet kubeadm kubectl

cat >/etc/crio/crio.conf.d/11-crio.conf <<EnD
[crio.runtime]
default_runtime = "crun"
conmon_cgroup = "pod"
cgroup_manager = "cgroupfs"
EnD

systemctl start crio.service

# Enable IPv4 forwarding, probably on the host
modprobe br_netfilter
sysctl -w net.ipv4.ip_forward=1

{
  # Run the preflight phase
  kubeadm init \
    --ignore-preflight-errors Swap \
    phase preflight

  # Set up the kubelet
  kubeadm init phase kubelet-start

  # Edit the kubelet configuration file
  echo "failSwapOn: false" >>/var/lib/kubelet/config.yaml
  sed -i 's/cgroupDriver: systemd/cgroupDriver: cgroupfs/' /var/lib/kubelet/config.yaml

  # Tell kubeadm to carry on from here
  kubeadm init \
    --pod-network-cidr=10.244.0.0/16 \
    --ignore-preflight-errors Swap \
    --skip-phases=preflight,kubelet-start
}
```

Verify that the cluster is ready:

```
# kubectl get pods -n kube-system --kubeconfig /etc/kubernetes/super-admin.conf 
NAME                                   READY   STATUS    RESTARTS   AGE
coredns-76f75df574-stpzc               1/1     Running   0          47m
coredns-76f75df574-vgdj6               1/1     Running   0          47m
etcd-1d371eeacf8c                      1/1     Running   0          47m
kube-apiserver-1d371eeacf8c            1/1     Running   0          47m
kube-controller-manager-1d371eeacf8c   1/1     Running   0          47m
kube-proxy-xs26j                       1/1     Running   0          47m
kube-scheduler-1d371eeacf8c            1/1     Running   0          47m
```

View then remove the taint on the control-plane node:

```
kubectl describe nodes | grep Taints

kubectl taint nodes --all node-role.kubernetes.io/control-plane:NoSchedule-
```

Create a busybox pod:

```
kubectl run -ti --rm busybox --image=busybox sh
# ping 8.8.8.8
```

