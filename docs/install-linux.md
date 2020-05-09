#### For Linux only

Fedora 32 has got rid of docker and **mokctl doesn't work with podman yet** - watch this space! (It's in progress...)

Note for Fedora users: Cgroups2 needs to be disabled, see [Common F31 bugs - Fedora Project Wiki](https://fedoraproject.org/wiki/Common_F31_bugs#Docker_package_no_longer_available_and_will_not_run_by_default_.28due_to_switch_to_cgroups_v2.29), which amounts to typing the following command then rebooting: `sudo grubby --update-kernel=ALL --args=&quot;systemd.unified_cgroup_hierarchy=0&quot;`

To build and install from source:

```bash
git clone https://github.com/mclarkson/my-own-kind.git
cd my-own-kind
```

Then EITHER build your own `mokctl` docker image and add a bash/zsh alias to it:

```bash
make mokctl-docker

alias mokctl=&#39;docker run --rm --privileged -ti -v /var/run/docker.sock:/var/run/docker.sock -v ~/.mok/:/root/.mok/ -e TERM=xterm-256color local/mokctl&#39;
```

OR, install into `/usr/local/bin`:

```bash
make test
sudo make install
```

Then use `mokctl`:

```bash
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

Also remove the docker images if required:

- local/mokctl

- local/mok-centos-7-v1.18.2

- docker

- centos
