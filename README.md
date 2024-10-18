# MOK - Run Kubernetes on your laptop

Current kubernetes version: 1.31

*Requirements*

* Fedora 40
* Podman or Docker
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

*Create a multi node kuberenetes cluster*

```bash
sudo mok create cluster myk8s --masters 1 --workers 1
```

*Run some kubectl commands*

```bash
export KUBECONFIG=/var/tmp/admin-myk8s.conf
kubectl get nodes
kubectl get pods --all-namespaces
```

```bash
# --privileged is required if you want to `ping`
kubectl run --privileged --rm -ti alpine --image alpine /bin/sh
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
```

Then delete the podman/docker images that were built by `mok build`.

## Known Issues

* Creating a cluster with a load balancer, `--with-lb`, currently fails

## Some Features

* Builds kubernetes master and worker nodes in containers
* Very simple to use without need for YAML files
* After creating the image a single node cluster builds in under 60 seconds
* For multi-node clusters the 'create cluster' command returns only when kubernetes is completely ready, with all nodes and pods up and ready.
* Can skip setting up kubernetes on the master and/or worker node (good for learning!)
  * In this case the set-up scripts are placed in `/root` in the containers and can be run by hand
  * Can do kubernetes the hard way (see [kthwic](https://github.com/my-own-kind/kubernetes-the-hard-way-in-containers))
* `mok build` and `mok create` can show extensive logs with `--tailf`

* [Full Documentation](https://github.com/bashtools/mok-docs/tree/master/docs)
