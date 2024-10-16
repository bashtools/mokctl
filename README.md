# MOK - Kubernetes on your laptop

*Requirements*

* An old laptop with 8 GB of memory
* Fedora 40 Desktop
* Cgroups v2 enabled - the default for Fedora 40
* Podman
* 5 GB of free disk space

*Install* to `/usr/local/bin`

```bash
git clone https://github.com/bashtools/mok.git
cd mok
sudo make install
```
```
export PATH=/usr/local/bin:$PATH
```

*First use*

```bash
sudo mok build image
```

*Create a multi node kuberenetes cluster* (k8s v1.30.0)

```bash
sudo mok create cluster myk8s --masters 1 --workers 1
```

*Run some kubectl commands*

```bash
export KUBECONFIG=/var/tmp/admin-myk8s.conf
kubectl get nodes
kubectl get pods --all-namespaces
kubectl run --rm -ti alpine --image alpine /bin/sh
```

*Get help*

```bash
sudo mok -h
sudo mok create -h
```

*Delete the cluster*

```bash
sudo mok delete cluster myk8s
```

*Uninstall mok completely*

```bash
rm -rf mok/
sudo rm /usr/local/bin/mok
sudo podman rmi localhost/local/mok-image-v1.30.0
```

## Known Issues

* Creating a single node cluster:
  * Containers created with `kubectl run ...` cannot reach the Internet
  * Multi-node clusters do not have this problem
* Creating a cluster with a load balancer, `--with-lb`, currently fails

## Some Features

* Builds kubernetes master and worker nodes in containers
* Very simple to use without need for YAML files
* After creating the image a single node cluster builds in under 60 seconds
* For multi-node clusters the 'create cluster' command returns only when kubernetes is completely ready, with all nodes and pods up and ready.
* Can skip setting up kubernetes on the master and/or worker node (good for learning!)
  * In this case the set-up scripts are placed in `/root` in the containers and run by hand
  * Can do kubernetes the hard way (see [kthwic](https://github.com/my-own-kind/kubernetes-the-hard-way-in-containers))
* `mok build` and `mok create` can show extensive logs with '--tailf'

* [Full Documentation](https://github.com/bashtools/mok-docs/tree/master/docs)
