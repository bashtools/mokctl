# Mokctl

*Install* to `/usr/local/bin`

```bash
git clone https://github.com/bashtools/mokctl.git
cd mokctl
sudo make install
export PATH=$PATH:/usr/local/bin
```

*First use*

```bash
mokctl build image
```




## Features

* Tracks the latest stable version

* After downloading 'build' images a single node cluster builds in under 60 seconds

* Very simple to use without need for YAML files

* Builds kubernetes master and worker nodes in containers

* Can create multi-master and multi-node clusters

* Can create an haproxy load balancer to front master nodes with '--with-lb'

* For multi-node clusters the 'create cluster' command returns when kubernetes is completely ready, with all nodes and pods up and ready.

* Can skip master, worker, or load balancer set up
  
  * In this case the set-up scripts are placed in `/root` in the containers
  
  * The set-up scripts can be run by hand
  
  * Can do kubernetes the hard way (see [kthwic](https://github.com/my-own-kind/kubernetes-the-hard-way-in-containers))

* Each release tested by AI and test logs saved in e2e-logs

* Build and create can show extensive logs with '--tailf'

* Supports docker, podman and moby

* Written in Bash in the style of Go for maintainability - see [Why Bash?](https://github.com/my-own-kind/mokctl-docs/blob/master/docs/faq.md#why-bash) and `src/`

### Install on Linux, Mac or Windows

> Note for **Fedora Linux** users: Cgroups 2 must be disabled. See [Linux Installation Options](/docs/install-linux.md).

Ensure [Docker](https://www.docker.com/get-started) or [Moby](https://github.com/moby/moby) are installed first.

Add the following to your shell startup file, for example `~/.bashrc` or `~/.zshrc`:

```bash
alias mokbox='docker run --rm -ti --hostname mokbox --name mokbox -v /var/run/docker.sock:/var/run/docker.sock -v /var/tmp:/var/tmp myownkind/mokbox'
```

Close the terminal and start it again so the alias is created.

Then 'log in' to the work container:

```bash
mokbox
```

Use `mokctl` and `kubectl`, which are already installed in the 'mokbox' container:

```bash
mokctl build image --get-prebuilt-image

mokctl create cluster myk8s --masters 1

export KUBECONFIG=/var/tmp/admin-myk8s.conf

kubectl get pods -A
```

Type `exit` or `Ctrl-d` to 'log out' of mokbox. The mokbox container will be deleted but the kubernetes cluster will remain, as will the `kubectl` file,`/var/tmp/admin-myk8s.conf`.

To remove the kubernetes cluster:

```bash
mokbox

export KUBECONFIG=/var/tmp/admin-myk8s.conf

mokctl delete cluster myk8s

exit
```

Two docker images will remain, 'myownkind/mokbox' and 'myownkind/mok-centos-7-v1.19.1'. Remove them to reclaim disk space, or keep them around to be able to quickly build kubernetes clusters.

See also:

* [Mokctl on Docker Hub](https://hub.docker.com/repository/docker/myownkind/mokctl) - to alias the `mokctl` command only, no mokbox.

* [Linux installation options](/docs/install-linux.md)

* [Full Documentation](https://github.com/my-own-kind/mokctl-docs)
