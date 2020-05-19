>  **Kubernetes the Hard Way using My Own Kind**
> 
> View a [screencast and transcript](/cmdline-player/kthw-11.md)
# Provisioning Pod Network Routes

Pods scheduled to a node receive an IP address from the node's Pod CIDR range. At this point pods can not communicate with other pods running on different nodes due to missing network routes to internal subnets on other worker nodes.

In this lab you will create a route on the host for each worker node that maps the node's Pod CIDR range to the node's internal IP address.

> There are [other ways](https://kubernetes.io/docs/concepts/cluster-administration/networking/#how-to-achieve-this) to implement the Kubernetes networking model.

## The Routing Table

In this section you will gather the information required to create routes in the host's networking stack on your laptop.

Print and save variables for the internal IP addresses for each worker instance:

```
{
WORKER1=$(sudo podman inspect kthw-worker-1 --format "{{.NetworkSettings.IPAddress}}")
WORKER2=$(sudo podman inspect kthw-worker-2 --format "{{.NetworkSettings.IPAddress}}")
WORKER3=$(sudo podman inspect kthw-worker-3 --format "{{.NetworkSettings.IPAddress}}")
echo $WORKER1
echo $WORKER2
echo $WORKER3
}
```

> output

```
10.88.1.43
10.88.1.44
10.88.1.45
```

## Routes

Create network routes for each worker instance:

```
{
  sudo ip ro add 10.200.1.0/24 via $WORKER1
  sudo ip ro add 10.200.2.0/24 via $WORKER2
  sudo ip ro add 10.200.3.0/24 via $WORKER3
}
```

List the routes in the `kubernetes-the-hard-way` network:

```
ip ro | grep 10.200
```

> output

```
10.200.1.0/24 via 10.88.1.43 dev cni-podman0 
10.200.2.0/24 via 10.88.1.44 dev cni-podman0 
10.200.3.0/24 via 10.88.1.45 dev cni-podman0 
```

Next: [Deploying the DNS Cluster Add-on](12-dns-addon.md)
