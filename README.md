# My Own Kind

![](docs/images/install-mokctl-linux.gif)

View a [Transcript of the screenscast](/cmdline-player/install-mokctl-linux.md).

## Summary

Build a verifiably conformant kubernetes cluster in containers.

### Try mokctl

Take note of the [Status](#status) below and the [Releases](https://github.com/mclarkson/my-own-kind/releases) page.

#### For Linux Operating Systems

Either [Podman](https://podman.io/) or [Docker](https://www.docker.com/get-started) must be installed frst. If both are installed `mokctl` will choose to use Podman.

If your distribution enables cgroups v2 then it must be disabled. Only Fedora do this right now, so for Fedora 31 or 32 do:

```bash
grubby --update-kernel=ALL --args="systemd.unified_cgroup_hierarchy=0"
```

To build and install from source:

```bash
git clone https://github.com/mclarkson/my-own-kind.git
cd my-own-kind
```

Install into `/usr/local/bin` (don't use mokctl if any tests fail):

```none
sudo make test
sudo make install
```

Then use `mokctl`:

```bash
alias mokctl="sudo mokctl"
mokctl build image
mokctl create cluster myk8s 1 0
```

Removal

```bash
# To remove mokctl
sudo make uninstall

# OR, to remove mokctl and the `~/.mok/` configuration directory
sudo make purge
```

#### For Non-Linux Operating Systems

Install [Docker](https://docs.docker.com/get-docker/) if you don't have it already.

Paste the following alias into your teminal:

```bash
alias mokctl='docker run --rm --privileged -ti -v /var/run/docker.sock:/var/run/docker.sock -v ~/.mok/:/root/.mok/ -e TERM=xterm-256color mclarkson/mokctl'
```

Then use mokctl:

```bash
mokctl build image

mokctl create cluster myk8s 1 0

export KUBECONFIG=~/.mok/admin.conf

kubectl get pods -A

kubectl run -ti --image busybox busybox sh
```

See: [Mokctl on Docker Hub](https://hub.docker.com/r/mclarkson/mokctl).

## Status

**Mokctl Utility**

| OS        | Termnal          | Status                       |
| --------- | ---------------- | ---------------------------- |
| Fedora 31 | Gnome Terminal   | Works - must disable cgroup2 |
| Fedora 32 | Gnome Terminal   | Works - must disable cgroup2 |
| Mac OS    | Default terminal | ?                            |
| Windows   | Cygwin           | ?                            |

## Documentation

To see how `mokctl` was created go to the [docs section](/docs/README.md).

## Kubernetes the Hard Way - on your laptop

These documents and screencasts show how to use `mokctl` on Fedora 32, with Podman, to create a 6 node kubernetes cluster and external load balancer on your laptop or desktop computer.

> NOTE: This is in progress

| Document                                                                                                               | Transcript + Screencast                |
| ---------------------------------------------------------------------------------------------------------------------- |:--------------------------------------:|
| [Start Page](/docs/k8shardway.md)                                                                                      |                                        |
| [01-prerequisites.md](/docs/kubernetes-the-hard-way/01-prerequisites.md)                                               |                                        |
| [02-client-tools.md](/docs/kubernetes-the-hard-way/02-client-tools.md)                                                 | [kthw-2.md](/cmdline-player/kthw-2.md) |
| [03-compute-resources.md](/docs/kubernetes-the-hard-way/03-compute-resources.md)                                       | [kthw-3.md](/cmdline-player/kthw-3.md) |
| [04-certificate-authority.md](/docs/kubernetes-the-hard-way/04-certificate-authority.md)                               | [kthw-4.md](/cmdline-player/kthw-4.md) |
| [05-kubernetes-configuration-files.md](/docs/kubernetes-the-hard-way/05-kubernetes-configuration-files.md)             | [kthw-5.md](/cmdline-player/kthw-5.md) |
| [06-data-encryption-keys.md](/docs/kubernetes-the-hard-way/06-data-encryption-keys.md)                                 | [kthw-6.md](/cmdline-player/kthw-6.md) |
| [07-bootstrapping-etcd.md](/docs/kubernetes-the-hard-way/07-bootstrapping-etcd.md)                                     | [kthw-7.md](/cmdline-player/kthw-7.md) |
| [08-bootstrapping-kubernetes-controllers.md](/docs/kubernetes-the-hard-way/08-bootstrapping-kubernetes-controllers.md) | [kthw-8.md](/cmdline-player/kthw-8.md) |
| ...                                                                                                                    |                                        |
| ...                                                                                                                    |                                        |
| ...                                                                                                                    |                                        |
| ...                                                                                                                    |                                        |

## Contributing

Please check the 'Help Wanted' issues if you fancy helping.

All types of contributions are welcome, from bug reports, success stories, feature requests, fixing typppos, to coding. Also check the [CONTRIBUTING.md](/CONTRIBUTING.md) document.
