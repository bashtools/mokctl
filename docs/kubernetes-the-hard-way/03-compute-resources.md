> **My Own Kind changes:**
> 
> * Removed all GCP sections.
> * Changed 'using Ubuntu 18.04' to 'using CentOS 7'.
> * Added information for using `mokctl`.

# Provisioning Compute Resources

Kubernetes requires a set of machines to host the Kubernetes control plane and the worker nodes where containers are ultimately run.

## Networking

The Kubernetes [networking model](https://kubernetes.io/docs/concepts/cluster-administration/networking/#kubernetes-model) assumes a flat network in which containers and nodes can communicate with each other.

## Compute Instances

The compute instances in this lab will be provisioned using [CentOS](https://www.centos.org/) 7, which has good support for the [containerd container runtime](https://github.com/containerd/containerd). Each compute instance will be provisioned with a fixed private IP address to simplify the Kubernetes bootstrapping process.

### Kubernetes Controllers and Workers

Create three compute instances which will host the Kubernetes control plane and three instances that will host the workers.

```
mokctl create cluster --skipmastersetup --with-lb kthw 3 3
```

### Verification

List the containers:

```
mokctl get cluster kthw
```

> output

```
MOK_Cluster  Docker_ID     Container_Name  IP_Address
kthw         ab064d51c475  kthw-lb         172.17.0.5
kthw         23959611c611  kthw-master-1   172.17.0.2
kthw         e79d16f9ca20  kthw-master-2   172.17.0.3
kthw         96f1d14fce23  kthw-master-3   172.17.0.4
kthw         2c1ca0b3a663  kthw-worker-1   172.17.0.6
kthw         01004a396bd1  kthw-worker-2   172.17.0.7
kthw         01f56ba29160  kthw-worker-3   172.17.0.8
```

## Configuring Access

Use `docker` or `mokctl` to access the containers.  Either specify the name directly, like:

```
mokctl exec kthw-master-1
```

> output

```
root@kthw-master-1 /]#
```

Type `exit` or control-d to exit the container.

Or, choose from a list:

```
mokctl exec
```

> output

```
Choose the container to log in to:

1) kthw         5a59e995ac7f  kthw-master-1   172.17.0.8
2) kthw         5dee0c1ac0e0  kthw-master-2   172.17.0.9
3) kthw         eeadd19fca3e  kthw-master-3   172.17.0.10
4) kthw         0256ece9cdce  kthw-worker-1   172.17.0.11
5) kthw         f00fedcdde5f  kthw-worker-2   172.17.0.12
6) kthw         4f4d85da4750  kthw-worker-3   172.17.0.13

Choose a number (Enter to cancel)> 4
[root@kthw-worker-1 /]#
```

Next: [Provisioning a CA and Generating TLS Certificates](04-certificate-authority.md)
