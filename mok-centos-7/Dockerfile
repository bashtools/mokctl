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
