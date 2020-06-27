FROM centos:7
ARG CRICTL_VERSION
ARG K8SVERSION
ARG CRIO_MAJOR
ARG CRIO_MINOR
ARG CRIO_PATCH
# Tell systemd that it's running in a container
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
    && curl -L https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/$CRIO_MAJOR.$CRIO_MINOR:/$CRIO_MAJOR.$CRIO_MINOR.$CRIO_PATCH/CentOS_7/devel:kubic:libcontainers:stable:cri-o:$CRIO_MAJOR.$CRIO_MINOR:$CRIO_MAJOR.$CRIO_MINOR.$CRIO_PATCH.repo >/etc/yum.repos.d/devel:kubic:libcontainers:stable:cri-o:$CRIO_MAJOR.$CRIO_MINOR:$CRIO_MAJOR.$CRIO_MINOR.$CRIO_PATCH.repo \
    && yum install -y \
      cri-o \
      iptables \
      iproute-tc \
      openssl \
      socat \
      conntrack \
      ipset \
      kubelet-$K8SVERSION \
      kubeadm-$K8SVERSION \
      kubectl-$K8SVERSION \
      --disableexcludes=kubernetes \
    && sed -i 's/\(cgroup_manager =\).*/\1 "systemd"/' /etc/crio/crio.conf \
    && sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config \
    && sed -i 's/\(conmon = .*\)/#\1/' /etc/crio/crio.conf \
    && rm -f /etc/cni/net.d/100-crio-bridge.conf \
    && rm -f /etc/cni/net.d/200-loopback.conf \
    && sed -i 's/\(^driver = \).*/\1"vfs"/' /etc/containers/storage.conf \
    && systemctl enable crio \
    && curl -L https://github.com/kubernetes-sigs/cri-tools/releases/download/v$CRICTL_VERSION/crictl-v${CRICTL_VERSION}-linux-amd64.tar.gz --output crictl-v${CRICTL_VERSION}-linux-amd64.tar.gz \
    && tar zxvf crictl-v$CRICTL_VERSION-linux-amd64.tar.gz -C /usr/local/bin \
    && rm -f crictl-v$CRICTL_VERSION-linux-amd64.tar.gz \
    && mkdir -p /opt/cni/ \
    && ln -s /usr/libexec/cni /opt/cni/bin
COPY k8s.conf /etc/sysctl.d/k8s.conf
COPY 100-crio-bridge.conf-flannel /etc/cni/net.d/100-crio-bridge.conf
COPY kubelet-config /etc/sysconfig/kubelet
COPY entrypoint /usr/local/bin
VOLUME [ "/sys/fs/cgroup" ]
# SystemD's instuction to halt
STOPSIGNAL SIGRTMIN+3
ENTRYPOINT ["/usr/local/bin/entrypoint", "/usr/sbin/init"]
