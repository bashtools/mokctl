# Mokctl

*Requirements* (because this is what I have)

* Fedora 40 Desktop
* An old slow laptop with 8 GB of memory
* Cgroups 2 enabled (This is the default on Fedora 40)
* Podman
* 2 GB of free disk space

*Install* to `/usr/local/bin`

```bash
git clone https://github.com/bashtools/mokctl.git
cd mokctl
sudo make install
export PATH=$PATH:/usr/local/bin
```

*First use*

```bash
sudo mokctl build image
```

*Create a single node kuberenetes cluster*

```bash
sudo mokctl create cluster myk8s 1
```

*Get help*

```bash
sudo mokctl -h
```

*Delete the cluster*

```bash
mokctl delete cluster myk8s
```

*Uninstall mokctl completely*

```bash
rm -rf mokctl/
rm /usr/local/bin/mokctl
sudo podman rmi localhost/local/mokctl-image-v1.30.0
```

## Features

* After creating the image a single node cluster builds in under 60 seconds
* Very simple to use without need for YAML files
* Builds kubernetes master and worker nodes in containers
* Can create multi-master and multi-node clusters
* Can create an haproxy load balancer to front master nodes with '--with-lb'
* For multi-node clusters the 'create cluster' command returns when kubernetes is completely ready, with all nodes and pods up and ready.
* Can skip master, worker, or load balancer set up
  * In this case the set-up scripts are placed in `/root` in the containers
  * The set-up scripts can be run by hand
  * Can do kubernetes the hard way (see [kthwic](https://github.com/my-own-kind/kubernetes-the-hard-way-in-containers))
* `mokctl build` and `mokctl create` can show extensive logs with '--tailf'
* Written in Bash in the style of Go ! :) - see [Why Bash?](https://github.com/my-own-kind/mokctl-docs/blob/master/docs/faq.md#why-bash) and `src/`

* [Full Documentation](https://github.com/bashtools/mokctl-docs/tree/master/docs)
