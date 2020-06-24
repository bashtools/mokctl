# Linux Installation Options

The kubernetes cluster will 'Evict' Pods if disk space is below 10% (see [kubernetes/types.go](https://github.com/kubernetes/kubernetes/blob/454c13d09cab57065f722b6baa305b2104ed0e09/staging/src/k8s.io/kubelet/config/v1beta1/types.go#L572) to see the defaults). My Own Kind images take up about 3.5GB of disk space.

Either [Podman](https://podman.io/) or [Docker](https://www.docker.com/get-started) must be installed frst. If both are installed `mokctl` will choose to use Docker.

If your distribution enables cgroups v2 then it must be disabled. Only Fedora do this right now, so for Fedora 31 or 32 run the following line then reboot:

```bash
grubby --update-kernel=ALL --args="systemd.unified_cgroup_hierarchy=0"
```

> See also: [Common F31 bugs - Fedora Project Wiki](https://fedoraproject.org/wiki/Common_F31_bugs#Docker_package_no_longer_available_and_will_not_run_by_default_.28due_to_switch_to_cgroups_v2.29).

## Use a Work Container (MokBox)

As an alternative to installing `mokctl`, there is a container image, MokBox, that has `mokctl`, `kubectl` and `docker` already installed, then `exec` into the instance to build kubernetes clusters.

Download and run the container image, [myownkind/mokbox](https://hub.docker.com/repository/docker/myownkind/mokbox):

```bash
docker run --rm -ti --hostname mokbox --name mokbox \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /var/tmp:/var/tmp myownkind/mokbox
```

```bash
mokctl build image --get-prebuilt-image

mokctl create cluster myk8s --masters 1

export KUBECONFIG=/var/tmp/admin-myk8s.conf

kubectl get pods -A
```

**Creating an Alias**

Add the following to your shell startup file, for example `~/.bashrc` or `~/.zshrc`:

```bash
alias mokbox='docker run --rm -ti --hostname mokbox --name mokbox -v /var/run/docker.sock:/var/run/docker.sock -v /var/tmp:/var/tmp myownkind/mokbox';
```

Then run the work container using: `mokbox`.

The base image is Fedora. Additional software can be installed using `dnf`, or modify `my-own-kind/package/Dockerfile.mokbox` and rebuild the image to have the same tools each time.

## Install Mokctl using NPM

Using this method will install the `mokctl` command into `/usr/local/bin`.

Kubectl wil need to be downloaded separately.

To install from npm:

```bash
sudo npm install -g my-own-kind
```

Then use `mokctl`:

```bash
alias mokctl="sudo mokctl"
mokctl build image --get-prebuilt-image
mokctl create cluster myk8s --masters 1
```

Removal

```bash
sudo npm uninstall -g my-own-kind
```

## Install from source

To build and install from source:

```bash
git clone https://github.com/mclarkson/my-own-kind.git
cd my-own-kind
```

Install into `/usr/local/bin`:

```bash
make test
sudo make install
```

Then use `mokctl`:

```bash
mokctl build image --get-prebuilt-image
mokctl create cluster myk8s 1 0
```

Removal

```bash
# To remove mokctl
sudo make uninstall
```

Also remove the docker images if required:

- local/mokctl

- local/mok-centos-7-v1.18.2

- docker

- centos
