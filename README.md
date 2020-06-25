# My Own Kind

![](docs/images/install-mokctl-linux.gif)

View a [Transcript of the screenscast](docs/install-mokctl-linux.md).

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

Two docker images will remain, 'myownkind/mokbox' and 'myownkind/mok-centos-7-v1.18.3'. Remove them to reclaim disk space, or keep them around to be able to quickly build kubernetes clusters.

See also:

* [Mokctl on Docker Hub](https://hub.docker.com/repository/docker/myownkind/mokctl) - to alias the `mokctl` command only, no mokbox.

* [Linux installation options](/docs/install-linux.md)

* [Full Documentation](https://github.com/my-own-kind/mokctl-docs)

