# Notes

Getting mokctl up and running with kubernetes v1.29 and cri-o v1.29

```
podman build --env GO_VERSION=1.23.2 -t debian-systemd .

podman run -d --systemd=always --name debian-systemd \
  --privileged -v /lib/modules:/lib/modules debian-systemd

podman exec -ti debian-systemd bash
```

Enable IP forwarding on the host

```
# Enable IPv4 forwarding, probably on the host
modprobe br_netfilter
sysctl -w net.ipv4.ip_forward=1
```

Install kubernetes

```
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
export KUBECONFIG=/etc/kubernetes/super-admin.conf
kubectl describe nodes | grep Taints
kubectl taint nodes --all node-role.kubernetes.io/control-plane:NoSchedule-
```

Create a busybox pod:

```
kubectl run -ti --rm busybox --image=busybox sh
# wget google.com
```

