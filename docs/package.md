# My Own Kind - Package

## Review

In [the previous section](/docs/build.md) we successfully built a Kind-like kubernetes single node cluster. We added a node to the cluster to see if it fixed the failing Sonobuoy test, which it did.

To build our own cluster we don't want to type all of those commands again so in this section we will package it up for easier installation. Later we will create a command line program that will do it all for us, but because we know how it works, we can customise it to our own needs if we want to.

## Problems

### No need to get CNI plugins

When the RPMs were installed with `yum`, the containernetwork-plugins rpm was automatically installed as a dependency for cri-o, which copied a whole set of CNI networking plugins into `/usr/libexec/cni`, so we didn't need to build them after all.

The plugin directory is referenced by the file `/etc/crio/crio.conf` and it already has the correct location, `/usr/libexec/cni`. It's interesting to note that nothing else uses these CNI plugins, only the container runtime does, which in our case is cri-o. Kubernetes will set up docker to use CNI if docker is used instead of cri-o.

This excellent blog post, [Understanding CNI (Container Networking Interface) Das Blinken Lichten](https://www.dasblinkenlichten.com/understanding-cni-container-networking-interface/), helped me to understand CNI better. It's also explained well in ‘Kubernetes in Action’, section 11.4 Interpod Networking.

**Action**

Remove all code that downloads CNI plugins manually to fix this problem.

### Keeping the same IP addresses

If, when we have a full cluster, we stop the cluster components, the re-start them, there is a distinct possibility that the master node (or load balancer) will get a different IP address.If this happens then the worker nodes will not be able to contact the master node. In fact, none of the nodes like coming up with different IP addresses to the one's they had previoiusly.

The same problem exists with Kind. The use-case for kind is that when finished with the cluster it should be deleted using `kind`, not stopped using `docker`.

**Action**

A quick [duckduckgo](https://duckduckgo.com) search came up with: [Assign static IP to Docker container - Stack Overflow](https://stackoverflow.com/questions/27937185/assign-static-ip-to-docker-container). This might be a simple option.

### Errors in Logs

Errors show up in the logs - use `journalctl -xef` to see them. In particular it shows that the kubelets can see all containers - not just the containers local to itself, and they think that there's a problem. This might use precious cpu but does not seem to cause any other problems.

**Action**

Investigate further. Kind does not exhibit this behaviour.

Kind kubelets: max 3.5% CPU when idle.

Mok kubelets: max

## Packaging

In the last Lab we identified the steps required to set up a node that's ready to be a master or worker node in, [Step 2: Copy the next commands and paste as one big command](/docs/build.md#step-2-copy-the-next-commands-and-paste-as-one-big-command). After the review we see that we don't need CNI plugins to be built manually so the following script shows the extra steps that need to be done:

```bash
{
  cat >/etc/sysctl.d/k8s.conf <<EnD
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EnD
  sysctl --system

  CRIO_VERSION=1.17
  curl -L -o /etc/yum.repos.d/devel:kubic:libcontainers:stable.repo https://download.opensuse.org/repositories/devel:kubic:libcontainers:stable/CentOS_7/devel:kubic:libcontainers:stable.repo
  curl -L -o /etc/yum.repos.d/devel:kubic:libcontainers:stable:cri-o:$CRIO_VERSION.repo https://download.opensuse.org/repositories/devel:kubic:libcontainers:stable:cri-o:$CRIO_VERSION/CentOS_7/devel:kubic:libcontainers:stable:cri-o:$CRIO_VERSION.repo

  # Kubernetes needs the traffic control binary, tc.
  # Installing cri-o also installs cni binaries.
  yum -y install cri-o iptables iproute-tc

  # Comment out hard-coded path to conmon. It's already in the path so will be found
  # and the existing hard coded one is not right for our system
  sed -i 's/\(conmon = .*\)/#\1/' /etc/crio/crio.conf
  # Also change cgroup_manager to cgroupfs rather than systemd
  sed -i 's/\(cgroup_manager =\).*/\1 "cgroupfs"/' /etc/crio/crio.conf

  # Write a new CNI crio bridge file without ipv6 enabled as it breaks crio.
  cat >/etc/cni/net.d/100-crio-bridge.conf <<EnD
{
    "cniVersion": "0.3.1",
    "name": "crio-bridge",
    "type": "bridge",
    "bridge": "cni0",
    "isGateway": true,
    "ipMasq": true,
    "hairpinMode": true,
    "ipam": {
        "type": "host-local",
        "routes": [
            { "dst": "0.0.0.0/0" }

        ],
        "ranges": [
            [{ "subnet": "10.88.0.0/16" }]
        ]
    }
}
EnD

  # Start crio
  systemctl enable --now crio

  CRICTL_VERSION="v1.17.0"
  curl -L https://github.com/kubernetes-sigs/cri-tools/releases/download/$CRICTL_VERSION/crictl-${CRICTL_VERSION}-linux-amd64.tar.gz --output crictl-${CRICTL_VERSION}-linux-amd64.tar.gz
  tar zxvf crictl-$CRICTL_VERSION-linux-amd64.tar.gz -C /usr/local/bin
  rm -f crictl-$CRICTL_VERSION-linux-amd64.tar.gz

  # There is no el8 yet, so using el7 packages
  cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-\$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
exclude=kubelet kubeadm kubectl
EOF

  # Set SELinux in permissive mode (effectively disabling it)
  setenforce 0
  sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

  yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes

  systemctl enable --now kubelet

  # Delete crio's cni config files
  rm -f /etc/cni/net.d/100-crio-bridge.conf
  rm -f /etc/cni/net.d/200-loopback.conf
}
```

Those commands can all be added to the Dockerfile.

I have done this and moved things around to make it tidy.

Take a look at [my-own-kind/mok-centos-7](/mok-centos-7) now to see the outcome.

The Dockerfile:

```bash
FROM centos:7
ARG CRIO_VERSION=1.17
ARG CRICTL_VERSION=v1.17.0
ARG K8SBINVER
ENV container docker
COPY kubernetes.repo /etc/yum.repos.d/kubernetes.repo
RUN (cd /lib/systemd/system/sysinit.target.wants/; for i in *; do \
    [ $i == systemd-tmpfiles-setup.service ] || rm -f $i; done); \
    rm -f /lib/systemd/system/multi-user.target.wants/*; \
    rm -f /etc/systemd/system/*.wants/*; \
    rm -f /lib/systemd/system/local-fs.target.wants/*; \
    rm -f /lib/systemd/system/sockets.target.wants/*udev*; \
    rm -f /lib/systemd/system/sockets.target.wants/*initctl*; \
    rm -f /lib/systemd/system/basic.target.wants/*; \
    rm -f /lib/systemd/system/anaconda.target.wants/*; \
    yum -y update \
    && curl -L -o /etc/yum.repos.d/devel:kubic:libcontainers:stable.repo https://download.opensuse.org/repositories/devel:kubic:libcontainers:stable/CentOS_7/devel:kubic:libcontainers:stable.repo \
    && curl -L -o /etc/yum.repos.d/devel:kubic:libcontainers:stable:cri-o:$CRIO_VERSION.repo https://download.opensuse.org/repositories/devel:kubic:libcontainers:stable:cri-o:$CRIO_VERSION/CentOS_7/devel:kubic:libcontainers:stable:cri-o:$CRIO_VERSION.repo \
    && yum install -y \
      cri-o \
      iptables \
      iproute-tc \
      kubelet$K8SBINVER \
      kubeadm$K8SBINVER \
      kubectl$K8SBINVER \
      --disableexcludes=kubernetes \
    && sed -i 's/\(cgroup_manager =\).*/\1 "cgroupfs"/' /etc/crio/crio.conf \
    && sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config \
    && sed -i 's/\(conmon = .*\)/#\1/' /etc/crio/crio.conf \
    && rm -f /etc/cni/net.d/100-crio-bridge.conf \
    && rm -f /etc/cni/net.d/200-loopback.conf \
    && systemctl enable crio \
    && systemctl enable kubelet \
    && curl -L https://github.com/kubernetes-sigs/cri-tools/releases/download/$CRICTL_VERSION/crictl-${CRICTL_VERSION}-linux-amd64.tar.gz --output crictl-${CRICTL_VERSION}-linux-amd64.tar.gz \
    && tar zxvf crictl-$CRICTL_VERSION-linux-amd64.tar.gz -C /usr/local/bin \
    && rm -f crictl-$CRICTL_VERSION-linux-amd64.tar.gz
COPY k8s.conf /etc/sysctl.d/k8s.conf
COPY 100-crio-bridge.conf /etc/cni/net.d/100-crio-bridge.conf
COPY entrypoint /usr/local/bin
VOLUME [ "/sys/fs/cgroup" ]
STOPSIGNAL SIGRTMIN+3
ENTRYPOINT ["/usr/local/bin/entrypoint"]
CMD ["/usr/sbin/init"]
```

You can see that any file created with a [here document](https://en.wikipedia.org/wiki/Here_document) has been converted to being copied into the image using COPY and it all looks clean and simple.

At the top of the Dockerfile we have:

```bash
ARG CRIO_VERSION=1.17
ARG CRICTL_VERSION=v1.17.0
ARG K8SBINVER
```

, which can be used to change the versions used.

### Using the new Dockerfile

Let's use the new Dockerfile to create a new cluster.

First delete the old cluster:

```bash
# Stop the cluster
docker stop master-1 node-1

# Delete them too
docker rm master-1 node-1
```

To start a new cluster with the new Dockerfile run the following:

```bash
{
  # Clone this repo
  git clone https://github.com/mclarkson/my-own-kind.git

  # Build container image
  cd my-own-kind/mok-centos-7
  docker build -t local/mok-centos-7 .

  # Start a master-1 and node-1
  docker run --privileged \
    -v /sys/fs/cgroup:/sys/fs/cgroup:ro \
    -v /lib/modules:/lib/modules:ro \
    --tmpfs /run --tmpfs /tmp --rm -d \
    --name master-1 \
    --hostname master-1 \
    local/mok-centos-7

  docker run --privileged \
    -v /sys/fs/cgroup:/sys/fs/cgroup:ro \
    -v /lib/modules:/lib/modules:ro \
    --tmpfs /run --tmpfs /tmp --rm -d \
    --name node-1 \
    --hostname node-1 \
    local/mok-centos-7
}
```
