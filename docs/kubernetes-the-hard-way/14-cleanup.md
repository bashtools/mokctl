>  **Kubernetes the Hard Way using My Own Kind**
> 
> View a [screencast and transcript](/cmdline-player/kthw-14.md)
# Cleaning Up

In this lab you will delete the compute resources created during this tutorial.

## Compute Instances

Delete the load balancer, controller and worker compute instances:

```
sudo mokctl delete cluster kthw
y
```

Delete the podman container we started to keep your laptop clean:

```
podman stop kthw
podman rm kthw
```

Delete the directory containing all the certificates:

```
rm -rf kthw-certs
```

## Networking

Delete the host routing rules:

```
ip ro | grep 10.200 | xargs -d'\n' -n1 sudo bash -c eval ip ro del
```

