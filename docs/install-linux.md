#### For Linux only

Fedora 32 removed docker and replaced it with [Podman](https://podman.io). Mokctl now supports Podman out-of-the-box and will choose Podman over Docker if both are installed.

Install Podman or Docker if one of them is not installed already.

Note for Fedora users: Cgroups2 needs to be disabled, see [Common F31 bugs - Fedora Project Wiki](https://fedoraproject.org/wiki/Common_F31_bugs#Docker_package_no_longer_available_and_will_not_run_by_default_.28due_to_switch_to_cgroups_v2.29), which amounts to typing the following command then rebooting: `sudo grubby --update-kernel=ALL --args=&quot;systemd.unified_cgroup_hierarchy=0&quot;`

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
