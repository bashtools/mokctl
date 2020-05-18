>  **Kubernetes the Hard Way using My Own Kind**
> 
> View a [screencast and transcript](/cmdline-player/kthw-7.md)

# Bootstrapping the etcd Cluster

Kubernetes components are stateless and store cluster state in [etcd](https://github.com/etcd-io/etcd). In this lab you will bootstrap a three node etcd cluster and configure it for high availability and secure remote access.

## Prerequisites

The commands in this lab must be run on each controller instance: `kthw-master-1`, `kthw-master-2`, and `kthw-master-3`. Login to each controller instance using the `mokctl` command. Example:

```
mokctl exec kthw-master-1
```

### Running commands in parallel with tmux

[tmux](https://github.com/tmux/tmux/wiki) can be used to run commands on multiple compute instances at the same time. See the [Running commands in parallel with tmux](01-prerequisites.md#running-commands-in-parallel-with-tmux) section in the Prerequisites lab.

## Bootstrapping an etcd Cluster Member

Before logging in to the masters we need to copy the cluster-list to each master node:

```
for instance in kthw-master-1 kthw-master-2 kthw-master-3; do
  sudo podman cp kthw-certs/cluster-list.txt ${instance}:/root/
done
```

Use `tmux` to log in to all three masters at the same time:

```
tmux
tmux set status off
tmux split
tmux split
tmux select-layout even-vertical
^aj
sudo mokctl exec kthw-master-1
^aj
sudo mokctl exec kthw-master-2
^aj
sudo mokctl exec kthw-master-3
^a^x
clear
```

`mokctl` installed a few kubernetes services ready for set up.

Ensure all existing kubernetes services are deleted:

```
yum -y remove kubelet kubeadm cri-o cri-tools runc criu
```

Install `wget` using `yum`:

```
yum -y install wget
```

### Download and Install the etcd Binaries

Change directory to the HOME directory:

```
cd
```

Download the official etcd release binaries from the [etcd](https://github.com/etcd-io/etcd) GitHub project:

```
wget "https://github.com/etcd-io/etcd/releases/download/v3.4.0/etcd-v3.4.0-linux-amd64.tar.gz"
```

Extract and install the `etcd` server and the `etcdctl` command line utility:

```
{
  tar -xvf etcd-v3.4.0-linux-amd64.tar.gz 2>/dev/null
  mv etcd-v3.4.0-linux-amd64/etcd* /usr/local/bin/
}
```
### Configure the etcd Server

```
{
  mkdir -p /etc/etcd /var/lib/etcd
  cp ca.pem kubernetes-key.pem kubernetes.pem /etc/etcd/
}
```

The instance internal IP address will be used to serve client requests and communicate with etcd cluster peers. Retrieve the internal IP address for the current compute instance:


```
INTERNAL_IP=$(ip ro get default 8.8.8.8 | head -n 1 | cut -f 7 -d " ")
echo $INTERNAL_IP
```

Also set some variables for all of the master nodes:

```
IP_MASTER_1=$(grep kthw-master-1 /root/cluster-list.txt | awk '{ print $NF; }')
echo $IP_MASTER_1
IP_MASTER_2=$(grep kthw-master-2 /root/cluster-list.txt | awk '{ print $NF; }')
echo $IP_MASTER_2
IP_MASTER_3=$(grep kthw-master-3 /root/cluster-list.txt | awk '{ print $NF; }')
echo $IP_MASTER_3
```

Each etcd member must have a unique name within an etcd cluster. Set the etcd name to match the hostname of the current compute instance:

```
ETCD_NAME=$(hostname -s)
```

Create the `etcd.service` systemd unit file:

```
cat <<EOF | tee /etc/systemd/system/etcd.service
[Unit]
Description=etcd
Documentation=https://github.com/coreos
[Service]
Type=notify
ExecStart=/usr/local/bin/etcd \\
  --name ${ETCD_NAME} \\
  --cert-file=/etc/etcd/kubernetes.pem \\
  --key-file=/etc/etcd/kubernetes-key.pem \\
  --peer-cert-file=/etc/etcd/kubernetes.pem \\
  --peer-key-file=/etc/etcd/kubernetes-key.pem \\
  --trusted-ca-file=/etc/etcd/ca.pem \\
  --peer-trusted-ca-file=/etc/etcd/ca.pem \\
  --peer-client-cert-auth \\
  --client-cert-auth \\
  --initial-advertise-peer-urls https://${INTERNAL_IP}:2380 \\
  --listen-peer-urls https://${INTERNAL_IP}:2380 \\
  --listen-client-urls https://${INTERNAL_IP}:2379,https://127.0.0.1:2379 \\
  --advertise-client-urls https://${INTERNAL_IP}:2379 \\
  --initial-cluster-token etcd-cluster-0 \\
  --initial-cluster kthw-master-1=https://$IP_MASTER_1:2380,kthw-master-2=https://$IP_MASTER_2:2380,kthw-master-3=https://$IP_MASTER_3:2380 \\
  --initial-cluster-state new \\
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5
[Install]
WantedBy=multi-user.target
EOF
```

### Start the etcd Server

```
{
  systemctl daemon-reload
  systemctl enable etcd
  systemctl start etcd
}
```

## Verification

List the etcd cluster members:

```
ETCDCTL_API=3 etcdctl member list \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/etcd/ca.pem \
  --cert=/etc/etcd/kubernetes.pem \
  --key=/etc/etcd/kubernetes-key.pem
```

> output

```
3a57933972cb5131, started, kthw-master-3, https://10.88.1.22:2380, https://10.88.1.22:2379
f98dc20bce6225a0, started, kthw-master-1, https://10.88.1.20:2380, https://10.88.1.20:2379
ffed16798470cab5, started, kthw-master-2, https://10.88.1.21:2380, https://10.88.1.21:2379
```

Log out of the master nodes:

```
exit
exit
```

Next: [Bootstrapping the Kubernetes Control Plane](08-bootstrapping-kubernetes-controllers.md)
