>  **Kubernetes the Hard Way using My Own Kind**
> 
> View a [screencast and transcript](/cmdline-player/kthw-3.md)

# Provisioning Compute Resources

Kubernetes requires a set of machines to host the Kubernetes control plane and the worker nodes where containers are ultimately run.

## Networking

The Kubernetes [networking model](https://kubernetes.io/docs/concepts/cluster-administration/networking/#kubernetes-model) assumes a flat network in which containers and nodes can communicate with each other.

## Compute Instances

The compute instances in this lab will be provisioned using [CentOS](https://www.centos.org/) 7, which has good support for the [containerd container runtime](https://github.com/containerd/containerd).

### Kubernetes Controllers and Workers

Create three compute instances which will host the Kubernetes control plane and three instances that will host the workers. Also create an instance that will be the external load balancer.

```
alias mokctl="sudo mokctl"
mokctl build image --get-prebuilt-image
mokctl create cluster --skipmastersetup --skiplbsetup --with-lb kthw 3 3
```

### Verification

List the containers:

```
mokctl get cluster kthw
```

## Configuring Access

Use `mokctl` to access the containers.  Either specify the name directly, like:

```
mokctl exec kthw-master-1
```

Type `exit` or control-d to exit the container.

```
exit
```
Or, choose from a list:

```
mokctl exec
5
```

Type `exit` or control-d to exit the container.

```
exit
```

Next: [Provisioning a CA and Generating TLS Certificates](04-certificate-authority.md)
