>  **Kubernetes the Hard Way using My Own Kind**
> 
> View a [screencast and transcript](/cmdline-player/kthw-8.md)
# Bootstrapping the Kubernetes Control Plane

In this lab you will bootstrap the Kubernetes control plane across three compute instances and configure it for high availability. You will also create an external load balancer that exposes the Kubernetes API Servers to remote clients. The following components will be installed on each node: Kubernetes API Server, Scheduler, and Controller Manager.

## Prerequisites

The commands in this lab must be run on each controller instance: `kthw-master-1`, `kthw-master-2`, and `kthw-master-3`. Login to each controller instance using the `mokctl` command. Example:

```
mokctl exec kthw-master-1
```

### Running commands in parallel with tmux

[tmux](https://github.com/tmux/tmux/wiki) can be used to run commands on multiple compute instances at the same time. See the [Running commands in parallel with tmux](01-prerequisites.md#running-commands-in-parallel-with-tmux) section in the Prerequisites lab.

## Provision the Kubernetes Control Plane

Use `tmux` to log in to all three masters at the same time:

```
tmux
tmux set status off
tmux split
tmux split
tmux select-layout even-vertical
tmux select-pane -D
sudo mokctl exec kthw-master-1
^aj
sudo mokctl exec kthw-master-2
^aj
sudo mokctl exec kthw-master-3
^a^x
clear
```

Change to root's home directory, where the certs are:

```
cd # <- All our certs are in root's home
```

Create the Kubernetes configuration directory:

```
mkdir -p /etc/kubernetes/config
```

Download the official Kubernetes release binaries:

```
wget "https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/linux/amd64/kube-apiserver" \
  "https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/linux/amd64/kube-controller-manager" \
  "https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/linux/amd64/kube-scheduler" \
  "https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/linux/amd64/kubectl"
```

Install the Kubernetes binaries:

```
{
  chmod +x kube-apiserver kube-controller-manager kube-scheduler kubectl
  mv kube-apiserver kube-controller-manager kube-scheduler kubectl /usr/local/bin/
}
```

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

### Configure the Kubernetes API Server

```
{
  mkdir -p /var/lib/kubernetes/
  mv ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem \
    service-account-key.pem service-account.pem \
    encryption-config.yaml /var/lib/kubernetes/
}
```

The instance internal IP address will be used to advertise the API Server to members of the cluster. Retrieve the internal IP address for the current compute instance:

```
INTERNAL_IP=$(ip ro get default 8.8.8.8 | head -n 1 | cut -f 7 -d " ")
echo $INTERNAL_IP
```
Create the `kube-apiserver.service` systemd unit file:

```
cat <<EOF | tee /etc/systemd/system/kube-apiserver.service
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes
[Service]
ExecStart=/usr/local/bin/kube-apiserver \\
  --advertise-address=${INTERNAL_IP} \\
  --allow-privileged=true \\
  --apiserver-count=3 \\
  --audit-log-maxage=30 \\
  --audit-log-maxbackup=3 \\
  --audit-log-maxsize=100 \\
  --audit-log-path=/var/log/audit.log \\
  --authorization-mode=Node,RBAC \\
  --bind-address=0.0.0.0 \\
  --client-ca-file=/var/lib/kubernetes/ca.pem \\
  --enable-admission-plugins=NamespaceLifecycle,NodeRestriction,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota \\
  --etcd-cafile=/var/lib/kubernetes/ca.pem \\
  --etcd-certfile=/var/lib/kubernetes/kubernetes.pem \\
  --etcd-keyfile=/var/lib/kubernetes/kubernetes-key.pem \\
  --etcd-servers=https://$MASTER1:2379,https://$MASTER2:2379,https://$MASTER3:2379 \\
  --event-ttl=1h \\
  --encryption-provider-config=/var/lib/kubernetes/encryption-config.yaml \\
  --kubelet-certificate-authority=/var/lib/kubernetes/ca.pem \\
  --kubelet-client-certificate=/var/lib/kubernetes/kubernetes.pem \\
  --kubelet-client-key=/var/lib/kubernetes/kubernetes-key.pem \\
  --kubelet-https=true \\
  --runtime-config=api/all \\
  --service-account-key-file=/var/lib/kubernetes/service-account.pem \\
  --service-cluster-ip-range=10.32.0.0/24 \\
  --service-node-port-range=30000-32767 \\
  --tls-cert-file=/var/lib/kubernetes/kubernetes.pem \\
  --tls-private-key-file=/var/lib/kubernetes/kubernetes-key.pem \\
  --v=2
Restart=on-failure
RestartSec=5
[Install]
WantedBy=multi-user.target
EOF
```

### Configure the Kubernetes Controller Manager

Move the `kube-controller-manager` kubeconfig into place:

```
mv kube-controller-manager.kubeconfig /var/lib/kubernetes/
```

Create the `kube-controller-manager.service` systemd unit file:

```
cat <<EOF | tee /etc/systemd/system/kube-controller-manager.service
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/kubernetes/kubernetes
[Service]
ExecStart=/usr/local/bin/kube-controller-manager \\
  --address=0.0.0.0 \\
  --cluster-cidr=10.200.0.0/16 \\
  --cluster-name=kubernetes \\
  --cluster-signing-cert-file=/var/lib/kubernetes/ca.pem \\
  --cluster-signing-key-file=/var/lib/kubernetes/ca-key.pem \\
  --kubeconfig=/var/lib/kubernetes/kube-controller-manager.kubeconfig \\
  --leader-elect=true \\
  --root-ca-file=/var/lib/kubernetes/ca.pem \\
  --service-account-private-key-file=/var/lib/kubernetes/service-account-key.pem \\
  --service-cluster-ip-range=10.32.0.0/24 \\
  --use-service-account-credentials=true \\
  --v=2
Restart=on-failure
RestartSec=5
[Install]
WantedBy=multi-user.target
EOF
```

### Configure the Kubernetes Scheduler

Move the `kube-scheduler` kubeconfig into place:

```
mv kube-scheduler.kubeconfig /var/lib/kubernetes/
```

Create the `kube-scheduler.yaml` configuration file:

```
cat <<EOF | tee /etc/kubernetes/config/kube-scheduler.yaml
apiVersion: kubescheduler.config.k8s.io/v1alpha1
kind: KubeSchedulerConfiguration
clientConnection:
  kubeconfig: "/var/lib/kubernetes/kube-scheduler.kubeconfig"
leaderElection:
  leaderElect: true
EOF
```

Create the `kube-scheduler.service` systemd unit file:

```
cat <<EOF | tee /etc/systemd/system/kube-scheduler.service
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/kubernetes/kubernetes
[Service]
ExecStart=/usr/local/bin/kube-scheduler \\
  --config=/etc/kubernetes/config/kube-scheduler.yaml \\
  --v=2
Restart=on-failure
RestartSec=5
[Install]
WantedBy=multi-user.target
EOF
```

### Start the Controller Services

```
{
  systemctl daemon-reload
  systemctl enable kube-apiserver kube-controller-manager kube-scheduler
  systemctl start kube-apiserver kube-controller-manager kube-scheduler
}
```

> Allow up to 10 seconds for the Kubernetes API Server to fully initialize.
```
sleep 10
```

### Verification

```
kubectl get componentstatuses --kubeconfig admin.kubeconfig
```

> output

```
NAME                 STATUS    MESSAGE              ERROR
controller-manager   Healthy   ok
scheduler            Healthy   ok
etcd-2               Healthy   {"health": "true"}
etcd-0               Healthy   {"health": "true"}
etcd-1               Healthy   {"health": "true"}
```

## RBAC for Kubelet Authorization

In this section you will configure RBAC permissions to allow the Kubernetes API Server to access the Kubelet API on each worker node. Access to the Kubelet API is required for retrieving metrics, logs, and executing commands in pods.

> This tutorial sets the Kubelet `--authorization-mode` flag to `Webhook`. Webhook mode uses the [SubjectAccessReview](https://kubernetes.io/docs/admin/authorization/#checking-api-access) API to determine authorization.

The commands in this section will effect the entire cluster and only need to be run once from one of the controller nodes.

Make the current pane full-screen:
```
^az
```

Create the `system:kube-apiserver-to-kubelet` [ClusterRole](https://kubernetes.io/docs/admin/authorization/rbac/#role-and-clusterrole) with permissions to access the Kubelet API and perform most common tasks associated with managing pods:

```
cat <<EOF | kubectl apply --kubeconfig admin.kubeconfig -f -
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRole
metadata:
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: system:kube-apiserver-to-kubelet
rules:
  - apiGroups:
      - ""
    resources:
      - nodes/proxy
      - nodes/stats
      - nodes/log
      - nodes/spec
      - nodes/metrics
    verbs:
      - "*"
EOF
```

The Kubernetes API Server authenticates to the Kubelet as the `kubernetes` user using the client certificate as defined by the `--kubelet-client-certificate` flag.

Bind the `system:kube-apiserver-to-kubelet` ClusterRole to the `kubernetes` user:

```
cat <<EOF | kubectl apply --kubeconfig admin.kubeconfig -f -
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: system:kube-apiserver
  namespace: ""
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:kube-apiserver-to-kubelet
subjects:
  - apiGroup: rbac.authorization.k8s.io
    kind: User
    name: kubernetes
EOF
```

## The Kubernetes Frontend Load Balancer

In this section you will provision an external load balancer to front the Kubernetes API Servers. The kubernetes-the-hard-way static IP address will be attached to the resulting load balancer.
### Provision a Network Load Balancer

We need to log out of the masters and log in to the load balancer instance.

Log out of the masters:

```
^az
exit
exit
```

Before logging in to the load balancer we need to copy over the clusterlist file:

```
sudo podman cp kthw-certs/cluster-list.txt kthw-lb:/root/
```

Log into the load balancer

```
sudo mokctl exec kthw-lb
```

Install HAProxy

```
yum -y install haproxy
```

Set some variables we will use to configure HAProxy:

```
INTERNAL_IP=$(ip ro get default 8.8.8.8 | head -n 1 | cut -f 7 -d " ")
echo $INTERNAL_IP
IP_MASTER_1=$(grep kthw-master-1 /root/cluster-list.txt | awk '{ print $NF; }')
echo $IP_MASTER_1
IP_MASTER_2=$(grep kthw-master-2 /root/cluster-list.txt | awk '{ print $NF; }')
echo $IP_MASTER_2
IP_MASTER_3=$(grep kthw-master-3 /root/cluster-list.txt | awk '{ print $NF; }')
echo $IP_MASTER_3
```

Configure HAProxy

```
{
cat <<EOF | tee /etc/haproxy/haproxy.cfg 
frontend kubernetes
    bind $INTERNAL_IP:6443
    option tcplog
    mode tcp
    default_backend kubernetes-master-nodes
backend kubernetes-master-nodes
    mode tcp
    balance roundrobin
    option tcp-check
    server master-1 $IP_MASTER_1:6443 check fall 3 rise 2
    server master-2 $IP_MASTER_2:6443 check fall 3 rise 2
    server master-3 $IP_MASTER_3:6443 check fall 3 rise 2
EOF
}
```

Start the HAProxy systemd unit file:

```
systemctl restart haproxy
```

### Verification

Make a HTTP request for the Kubernetes version info:

```
curl  https://$INTERNAL_IP:6443/version -k
```

> output

```
{
"major": "1",
"minor": "15",
"gitVersion": "v1.15.3",
"gitCommit": "2d3c76f9091b6bec110a5e63777c332469e0cba2",
"gitTreeState": "clean",
"buildDate": "2019-08-19T11:05:50Z",
"goVersion": "go1.12.9",
"compiler": "gc",
"platform": "linux/amd64"
}
```

Exit from the load balancer

```
exit
```

Next: [Bootstrapping the Kubernetes Worker Nodes](09-bootstrapping-kubernetes-workers.md)
