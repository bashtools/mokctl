>  **Kubernetes the Hard Way using My Own Kind**
> 
> View a [screencast and transcript](/cmdline-player/kthw-10.md)
# Configuring kubectl for Remote Access

In this lab you will generate a kubeconfig file for the `kubectl` command line utility based on the `admin` user credentials.

> Run the commands in this lab from the same directory used to generate the admin client certificates.

## The Admin Kubernetes Configuration File

Each kubeconfig requires a Kubernetes API Server to connect to. To support high availability the IP address assigned to the external load balancer fronting the Kubernetes API Servers will be used.

First we need to log back in to the podman container we created earlier:

```
podman exec -ti kthw bash
```

Change to the `/certs` directory, which is volume mounted to the host:

```
cd /certs
```

Generate a kubeconfig file suitable for authenticating as the `admin` user:

```
{
  KUBERNETES_PUBLIC_ADDRESS=$(grep kthw-lb /certs/cluster-list.txt | awk '{ print $NF; }')
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443
  kubectl config set-credentials admin \
    --client-certificate=admin.pem \
    --client-key=admin-key.pem
  kubectl config set-context kubernetes-the-hard-way \
    --cluster=kubernetes-the-hard-way \
    --user=admin
  kubectl config use-context kubernetes-the-hard-way
}
```

## Verification

Check the health of the remote Kubernetes cluster:

```
kubectl get componentstatuses
```

> output

```
NAME                 STATUS    MESSAGE             ERROR
controller-manager   Healthy   ok
scheduler            Healthy   ok
etcd-1               Healthy   {"health":"true"}
etcd-2               Healthy   {"health":"true"}
etcd-0               Healthy   {"health":"true"}
```

List the nodes in the remote Kubernetes cluster:

```
kubectl get nodes
```

> output

```
NAME            STATUS   ROLES    AGE    VERSION
kthw-worker-1   Ready    <none>   2m9s   v1.15.3
kthw-worker-2   Ready    <none>   2m9s   v1.15.3
kthw-worker-3   Ready    <none>   2m9s   v1.15.3
```

Finally, log out of the container:

```
exit
```

Next: [Provisioning Pod Network Routes](11-pod-network-routes.md)
