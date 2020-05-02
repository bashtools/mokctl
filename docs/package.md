# My Own Kind - Package

<!-- START doctoc generated TOC please keep comment here to allow auto update -->

<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [Review](#review)
- [Problems](#problems)
  - [No need to get CNI plugins](#no-need-to-get-cni-plugins)
  - [Keeping the same IP addresses](#keeping-the-same-ip-addresses)
  - [Errors in Logs](#errors-in-logs)
- [Packaging](#packaging)
  - [Using the new Dockerfile](#using-the-new-dockerfile)
    - [Set up master-1](#set-up-master-1)
    - [Join node-1 to the cluster](#join-node-1-to-the-cluster)
  - [Result](#result)
- [Scripted cluster creation and deletion](#scripted-cluster-creation-and-deletion)
  - [Adding the ‘do_’ functions](#adding-the-do_-functions)
- [Add tests](#add-tests)
  - [Install Bats](#install-bats)
  - [Write a test](#write-a-test)
  - [Install shUnit2](#install-shunit2)
  - [All done!](#all-done)
- [Trying it out](#trying-it-out)
  - [The End to End Experience](#the-end-to-end-experience)
- [What's Next?](#whats-next)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

</div>

## Review

In [the previous section](/docs/build.md) we successfully built a Kind-like kubernetes single node cluster. We added a node to the cluster to see if it fixed the failing Sonobuoy test, which it did.

To build our own cluster we don't want to type all of those commands again so in this section we will package it up for easier installation. Later we will create a command line program that will do it all for us.

## Problems

### No need to get CNI plugins

When the RPMs were installed with `yum`, the containernetwork-plugins rpm was automatically installed as a dependency for cri-o, which copied a whole set of CNI networking plugins into `/usr/libexec/cni`, so we didn't need to build them after all.

The plugin directory is referenced by the file `/etc/crio/crio.conf` and it already has the correct location: `/usr/libexec/cni`, which differs to the widely known, `/opt/cni/bin/`. It's interesting to note that nothing else uses these CNI plugins, only the container runtime does, which in our case is cri-o. Kubernetes will set docker up to use CNI if docker is used instead of cri-o.

This excellent blog post, [Understanding CNI (Container Networking Interface) Das Blinken Lichten](https://www.dasblinkenlichten.com/understanding-cni-container-networking-interface/), helped me to understand CNI better. It‘s also explained well in ‘Kubernetes in Action’, section 11.4 Interpod Networking.

**Action**

Remove all code that downloads CNI plugins manually to fix this problem.

### Keeping the same IP addresses

If, when we have a full cluster, we stop the cluster components, then re-start them, there is a distinct possibility that the master node (or load balancer) will get a different IP address. If this happens then the worker nodes will not be able to contact the master node. In fact, none of the nodes work properly if they re-start with different IP addresses.

The same problem exists with Kind. Kind does not mention this use case and their [Cluster Lifecycle](https://kind.sigs.k8s.io/docs/design/initial/#cluster-lifecycle) suggests that the user is expected to delete the cluster using the `kinddelete cluster` command, rather than stop it using `docker stop`.

**Action**

A quick [duckduckgo](https://duckduckgo.com) search came up with: [Assign static IP to Docker container - Stack Overflow](https://stackoverflow.com/questions/27937185/assign-static-ip-to-docker-container). This might be a simple solution.

### Errors in Logs

Errors show up in the logs - use `journalctl -xef` to see them. In particular it shows that the kubelets can see all containers running on the host, even those in the other containers. The kubelet gets confused because it can't find the container files the kernel says it has. This might use precious cpu but does not seem to cause any other problems.

**Action**

Investigate further. Kind does not exhibit this behaviour.

Kind kubelets: max 4% CPU when idle.

Mok kubelets: max 4% for the master. around 25% for the worker node.

This is a show-stopper and stops us from running lots of containers if we want to.

## Packaging

In the last Lab we identified the steps required to set up a node that's ready to be a master or worker node in: [Step 2: Copy the next commands and paste as one big command](/docs/build.md#step-2-copy-the-next-commands-and-paste-as-one-big-command).

After the above review we see that we don't need CNI plugins to be built manually so the following script shows all the extra steps that need to be done:

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

Those commands can all be added to the Dockerfile because they are not specific to any master or worker node.

Take a look at [my-own-kind/mok-centos-7](/mok-centos-7) now to see how the above commands have been added to the Dockerfile, and how the [Here Documents](https://stackoverflow.com/questions/2953081/how-can-i-write-a-heredoc-to-a-file-in-bash-script) have been saved as files and added as COPY commands [in the Dockerfile](/mok-centos-7/Dockerfile). I'll paste it next for easy comparison with the above shell code:

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

It all looks quite simple and much cleaner. It took a couple of hours to get it looking that simple - at first it still looked messy, and there were many change-code/test-build iterations but it does no more and no less than before (except it doesn't download CNI binaries!).

At the top of the Dockerfile we have:

```bash
ARG CRIO_VERSION=1.17
ARG CRICTL_VERSION=v1.17.0
ARG K8SBINVER
```

The ARGs can be used to change the versions used using the `--build-arg` option to docker. `K8SBINVER` - the kubernetes version, is empty, so the latest version of kubernetes will be installed.

### Using the new Dockerfile

Let's use the new Dockerfile to create a new cluster.

First delete the old cluster if you haven‘t already:

```bash
# Stop the cluster
docker stop master-1 node-1

# Delete them too
docker rm master-1 node-1
```

To start a new cluster with two nodes, master-1 and node-1, with the new Dockerfile run the following:

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
    --tmpfs /run --tmpfs /tmp -d \
    --name master-1 \
    --hostname master-1 \
    local/mok-centos-7

  docker run --privileged \
    -v /sys/fs/cgroup:/sys/fs/cgroup:ro \
    -v /lib/modules:/lib/modules:ro \
    --tmpfs /run --tmpfs /tmp -d \
    --name node-1 \
    --hostname node-1 \
    local/mok-centos-7
}
```

#### Set up master-1

As before, exec in:

```bash
docker exec -ti master-1 bash
```

Then copy and paste:

```bash
{
  # Run the preflight phase
  kubeadm init \
    --pod-network-cidr=10.244.0.0/16 \
    --ignore-preflight-errors Swap \
    phase preflight

  # Set up the kubelet
  kubeadm init phase kubelet-start

  # Edit the kubelet configuration file
  echo "failSwapOn: false" >>/var/lib/kubelet/config.yaml

  # Tell kubeadm to carry on from here
  kubeadm init \
    --pod-network-cidr=10.244.0.0/16 \
    --ignore-preflight-errors Swap \
    --skip-phases=preflight,kubelet-start
}
```

Kubeadm should display something similar to:

```none
Your Kubernetes control-plane has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join 172.17.0.2:6443 --token b0k447.ry24d2oudzb7ryk7 \
    --discovery-token-ca-cert-hash sha256:a03f5df648a12a384e691739777127465335d48069a8c918c599cbde7e71b277 

```

Run the top 3 code lines from the output, without `sudo`, like so:

```bash
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config
```

Save the text that your `kubeadm` produced for joining a node. We will run it at the end of setting up node-1.

Now `exit` the master-1 node.

#### Join node-1 to the cluster

Exec in:

```bash
docker exec -ti node-1 bash
```

Then copy and paste:

```bash
# We run our 'hack' now. This time it will run in the background.
while true; do
  [[ -e /var/lib/kubelet/config.yaml ]] && {
    echo "failSwapOn: false" >>/var/lib/kubelet/config.yaml
    break;
  }
  sleep 1
done &

# Paste the join-node output you got on the master-1 node and
# add the option to ignore that Swap is enabled.
# For example mine is:
kubeadm join 172.17.0.2:6443 --token b0k447.ry24d2oudzb7ryk7 \
    --discovery-token-ca-cert-hash sha256:a03f5df648a12a384e691739777127465335d48069a8c918c599cbde7e71b277 \
    --ignore-preflight-errors Swap


```

There was no need to do the phased kubeadm join that we did last time since it isn't granular enough anyway, so just the hack will do.

### Result

Success! It was alot easier than before but we have a show-stopper of a problem, where the `kubelet` uses way too much CPU.

To debug this problem it would probably help alot to be able to create and destroy clusters with one command.

## Scripted cluster creation and deletion

This can be accomplished with a simple shell script that will run the above commands for us. Note that we're not looking to create a fully fledged solution, just one that will make it quicker to try out fixes.

Looking at the above this is what we'll need for, ummm, `mokctl`:

1. The CLI interface:
   
   * `mokctl create cluster NAME NUM_MASTERS NUM_WORKERS`
   
   * `mokctl delete cluster NAME`

The CLI interface needs to behave like other kubernetes tools, which makes things a little more tricky. Let's code that now:

```bash
#!/usr/bin/env bash

# ===========================================================================
# GLOBALS
# ===========================================================================
# Don't change any globals

# The initial state for the state machine
STATE="COMMAND"

ERROR=1
OK=0

COMMAND=
SUBCOMMAND=

CREATE_CLUSTER_NAME=
CREATE_CLUSTER_NUM_MASTERS=
CREATE_CLUSTER_NUM_WORKERS=

DELETE_CLUSTER_NAME=

# ===========================================================================
main() {
# ===========================================================================
# Execution begins here

  parse_options "$@"

  case "$COMMAND" in
    create) do_create ;;
    delete) do_delete ;;
  esac

  exit 0
}

# ---------------------------------------------------------------------------
do_create() {
# ---------------------------------------------------------------------------
# Calls the correct command/subcommand function

  case $SUBCOMMAND in
    cluster) do_create_cluster ;;
  esac
}

# ---------------------------------------------------------------------------
do_create_cluster() {
# ---------------------------------------------------------------------------
# Creates a mok cluster. All user vars have been parsed and saved.
# Globals: CREATE_CLUSTER_NAME CREATE_CLUSTER_NUM_MASTERS
#          CREATE_CLUSTER_NUM_WORKERS
# No args expected

  if [[ -z $CREATE_CLUSTER_NAME ]]; then
    usage
    echo "Please provide the Cluster NAME to create."
    exit $ERROR
  fi

  if [[ -z $CREATE_CLUSTER_NUM_MASTERS || $CREATE_CLUSTER_NUM_MASTERS -le 0 ]]; then
    usage
    echo "Please provide the number of Masters to create. Must be 1 or more."
    exit $ERROR
  fi

  if [[ -z $CREATE_CLUSTER_NUM_WORKERS ]]; then
    usage
    echo "Please provide the number of Workers to create."
    exit $ERROR
  fi

  # Create master node(s)

  # Create worker node(s)
}

# ---------------------------------------------------------------------------
do_delete() {
# ---------------------------------------------------------------------------
# Calls the correct command/subcommand function
# No args expected

  case $SUBCOMMAND in
    cluster) do_delete_cluster ;;
  esac
}

# ---------------------------------------------------------------------------
do_delete_cluster() {
# ---------------------------------------------------------------------------
# Deletes a mok cluster. All user vars have been parsed and saved.
# Globals: DELETE_CLUSTER_NAME
# No args expected

  if [[ -z $DELETE_CLUSTER_NAME ]]; then
    usage
    echo "Please provide the Cluster NAME to delete."
    exit $ERROR
  fi

  # Delete worker nodes

  # Delete master nodes
}

# ===========================================================================
# FUNCTIONS FOR PARSING THE COMMAND LINE BELOW
# ===========================================================================

# ---------------------------------------------------------------------------
parse_options() {
# ---------------------------------------------------------------------------
# Uses a state machine to check all command line arguments
# Args:
#   arg1 - The arguments given to mokctl by the user on the command line

  set -- "$@"
  local ARGN=$#
  while [ "$ARGN" -ne 0 ]
  do
    case $1 in
      -h) usage
          exit 0
      ;;
      ?*) case "$STATE" in
            COMMAND) check_command_token $1
                   [[ $? -eq $ERROR ]] && {
                     usage
                     echo "Invalid COMMAND, '$1'."
                     echo
                     exit $ERROR
                   }
                   COMMAND="$1"
                 ;;
            SUBCOMMAND) check_subcommand_token $1
                   [[ $? -eq $ERROR ]] && {
                     usage
                     echo "Invalid SUBCOMMAND for $COMMAND, '$1'."
                     echo
                     exit $ERROR
                   }
                   SUBCOMMAND="$1"
                 ;;
            OPTION) check_option_token $1
                   [[ $? -eq $ERROR ]] && {
                     usage
                     echo "Invalid OPTION for $COMMAND $SUBCOMMAND, '$1'."
                     echo
                     exit $ERROR
                   }
                 ;;
            OPTION2) check_option2_token $1
                   [[ $? -eq $ERROR ]] && {
                     usage
                     echo "Invalid OPTION for $COMMAND $SUBCOMMAND, '$1'."
                     echo
                     exit $ERROR
                   }
                 ;;
            OPTION3) check_option3_token $1
                   [[ $? -eq $ERROR ]] && {
                     usage
                     echo "Invalid OPTION for $COMMAND $SUBCOMMAND, '$1'."
                     echo
                     exit $ERROR
                   }
                 ;;
            END) usage
                 echo -n "ERROR No more options expected, '$1' is unexpected"
                 echo " for '$COMMAND $SUBCOMMAND'"
                 exit $ERROR
                 ;;
            ?*) echo "Internal ERROR. Invalid state '$STATE'"
                exit $ERROR
          esac
      ;;
    esac
    shift 1
    ARGN=$((ARGN-1))
  done

  [[ -z $COMMAND ]] && {
    usage
    echo "No COMMAND supplied"
    exit $ERROR
  }
  [[ -z $SUBCOMMAND ]] && {
    usage
    echo "No SUBCOMMAND supplied"
    exit $ERROR
  }
}

# ---------------------------------------------------------------------------
check_command_token() {
# ---------------------------------------------------------------------------
# Check for a valid token in command state
# Args:
#   arg1 - token

  case $1 in
    create) COMMAND=create
      ;;
    delete) COMMAND=delete
      ;;
    ?*) return $ERROR
      ;;
  esac
  STATE="SUBCOMMAND"
}

# ---------------------------------------------------------------------------
check_subcommand_token() {
# ---------------------------------------------------------------------------
# Check for a valid token in subcommand state
# Args:
#   arg1 - token

  case $COMMAND in
    create) check_create_subcommand_token $1 ;;
    delete) check_delete_subcommand_token $1 ;;
  esac
}

# ---------------------------------------------------------------------------
check_create_subcommand_token() {
# ---------------------------------------------------------------------------
# Check for a valid token in subcommand state
# Args:
#   arg1 - token

  case $1 in
    cluster) SUBCOMMAND="cluster"
      ;;
    ?*) return $ERROR
      ;;
  esac

  STATE="OPTION"

  return $OK
}

# ---------------------------------------------------------------------------
check_delete_subcommand_token() {
# ---------------------------------------------------------------------------
# Check for a valid token in subcommand state
# Args:
#   arg1 - token

  case $1 in
    cluster) SUBCOMMAND="cluster"
      ;;
    ?*) return $ERROR
      ;;
  esac

  STATE=OPTION
}

# ---------------------------------------------------------------------------
check_option_token() {
# ---------------------------------------------------------------------------
# Check for a valid token in option state
# Args:
#   arg1 - token

  case $COMMAND in
    create)
      case $SUBCOMMAND in
        cluster) CREATE_CLUSTER_NAME="$1"
          STATE="OPTION2"
          ;;
      esac
      ;;
    delete)
      case $SUBCOMMAND in
        cluster) DELETE_CLUSTER_NAME="$1"
          STATE="END"
          ;;
      esac
      ;;
  esac
}

# ---------------------------------------------------------------------------
check_option2_token() {
# ---------------------------------------------------------------------------
# Check for a valid token in option2 state
# Args:
#   arg1 - token

  case $COMMAND in
    create)
      case $SUBCOMMAND in
        cluster) CREATE_CLUSTER_NUM_MASTERS="$1"
          STATE="OPTION3"
          ;;
      esac
      ;;
    delete)
      case $SUBCOMMAND in
        cluster) return $ERROR
          ;;
      esac
      ;;
  esac
}

# ---------------------------------------------------------------------------
check_option3_token() {
# ---------------------------------------------------------------------------
# Check for a valid token in option3 state
# Args:
#   arg1 - token

  case $COMMAND in
    create)
      case $SUBCOMMAND in
        cluster) CREATE_CLUSTER_NUM_WORKERS="$1"
          STATE="END"
          ;;
      esac
      ;;
    delete)
      case $SUBCOMMAND in
        cluster) return $ERROR
          ;;
      esac
      ;;
  esac
}

# ---------------------------------------------------------------------------
usage() {
# ---------------------------------------------------------------------------
# Every tool, no matter how small, should have help text!

  echo
  echo "Usage: mokctl [-h] <COMMAND> <SUBCOMMAND> [SUBCOMMAND_OPTIONS...]"
  echo
  echo "Global options:"
  echo
  echo "  -h - This help text"
  echo
  echo "Where COMMAND can be one of:"
  echo
  echo "  create"
  echo "  delete"
  echo
  echo "create SUBCOMMANDs:"
  echo
  echo "  cluster - Create a local kubernetes cluster."
  echo
  echo "create cluster options:"
  echo
  echo " Format:"
  echo
  echo "  create cluster NAME NUM_MASTERS NUM_WORKERS"
  echo
  echo "  NAME        - The name of the cluster. This will be used as"
  echo "                the prefix in the name for newly created"
  echo "                docker containers."
  echo "  NUM_MASTERS - The number of master containers."
  echo "  NUM_WORKERS - The number of worker containers."
  echo
  echo "delete SUBCOMMANDs:"
  echo
  echo "  cluster - Create a local kubernetes cluster."
  echo
  echo "delete cluster options:"
  echo
  echo " Format:"
  echo
  echo "  delete cluster NAME"
  echo
  echo "  NAME        - The name of the cluster to delete"
  echo
  echo "EXAMPLES"
  echo
  echo "Create a single node cluster:"
  echo "Note that the master node will be made schedulable for pods."
  echo
  echo "  mokctl create cluster mycluster 1 0"
  echo
  echo "Create a single master and single node cluster:"
  echo "Note that the master node will NOT be schedulable for pods."
  echo
  echo "  mokctl create cluster mycluster 1 1"
  echo
  echo "Delete a cluster:"
  echo
  echo "  mokctl delete cluster mycluster"
  echo
}

if ([ "$0" = "$BASH_SOURCE" ] || ! [ -n "$BASH_SOURCE" ]);
then
  main "$@"
fi

# vim:ft=bash:sw=2:et:ts=2:


```

The command line parser, starting in `parse_options()` above, implements a state machine, which will allow new functionality to be added in a scalable way. I thought I would put the work in right now to code a state machine just in case we need more commands later on. It's surprising how long scripts intended for limited use hang around so it's good to start off well, and indeed, kubernetes was initially a large set of shell scripts!

The code makes sure that valid commands, their sub-commands and their options are supplied in the right order for the parent context.

The work that we need doing will go into the two functions: `do_create_cluster()`, and `do_delete_cluster()`.

Let's code them now, and no surprises this time

### Adding the ‘do_’ functions

While writing the code I found I needed:

1. A way to build images.
   
   So I added a script, `embed-dockerfile.sh`, that bundles the whole `mok-centos-7` docker build directory as a compressed tar file, which is converted to base64 and written into the `mokctl` script between two comments.

```bash
a=$(tar cvz mok-centos-7 | base64 | sed 's/$/ \\/')
sed -r '/mok-centos-7-tarball-start/, /mok-centos-7-tarball-end/ c \
  #mok-centos-7-tarball-start \
cat <<'EnD' | base64 -d | tar xzv -C $TMPDIR \
'"$(echo "$a")"' \
EnD \
  #mok-centos-7-tarball-end' mokctl/mokctl >mokctl.deploy
```

2. An extension to the CLI interface.
   
   Now we also need to add to our CLI interface:
   
   `mokctl build image`
   
   `mokctl get clusters` 

3. An easy way to recreate `mokctl` when files change.
   
   Using [Make](https://ftp.gnu.org/old-gnu/Manuals/make-3.79.1/html_node/make_toc.html) and creating a `Makefile` is perfect for this. Type `make` and it will run the `embed-dockerfile.sh` script, and save the new `mokctl` as `mokctl.deploy`. Running `make` will only rebuild `mokctl.deploy` if a file changes in either of the directories: `mokctl/` and/or `mok-centos-7/`.
   
   The `make` utility can also install `mokctl` in `/usr/local/bin`. To do that type `sudo make install`.

```bash
.PHONY: all install

all: mokctl.deploy

mokctl.deploy: mokctl/mokctl mok-centos-7
    bash mokctl/embed-dockerfile.sh

install:
    chmod +x mokctl.deploy
    install mokctl.deploy /usr/local/bin/mokctl
```

Now, as I'm getting ready to finish this off I realised I haven't written any tests. We really will need some so let's do that first.

## Add tests

We need to have some sort of tests to verify our code. This is especially important to enable others to contribute to a project. If there are no tests then it's hard to verify if a Pull Request breaks the code.

Let's add some tests using [GitHub - sstephenson/bats: Bash Automated Testing System](https://github.com/sstephenson/bats). It's the first thing DuckDuckGo showed me.

### Install Bats

Fedora:

`dnf install bats`

### Write a test

```bash
#!/usr/bin/env bats

@test "Testing 'make'" {
  run make
  [ $status -eq 0 ]
}

@test "Was mokctl.deploy created and is it executable" {
  [ -x mokctl.deploy ]
}

@test "Checking for build directory made by create_docker_build_dir()" {
  local dir
  source mokctl.deploy
  create_docker_build_dir
  dir="$TMPDIR/mok-centos-7"
  [[ -e "$dir/Dockerfile" &&
     -e "$dir/100-crio-bridge.conf" &&
     -e "$dir/entrypoint" &&
     -e "$dir/k8s.conf" &&
     -e "$dir/kubernetes.repo" &&
     -e "$dir/README.md" ]] 
}

@test "Checking cleanup() deletes TMPDIR" {
  source mokctl.deploy
  create_docker_build_dir
  cleanup
  [[ ! -e $TMPDIR ]]
}

# ---- parser checks ----

@test "No args should fail" {
  run ./mokctl.deploy
  [[ ${lines[0]} == "Usage: mokctl"* ]]
}

@test "One arg should fail" {
  run ./mokctl.deploy arg1
  [[ ${lines[0]} == "Usage: mokctl"* ]]
}

@test "Not enough options: 'mokctl create cluster'" {
  run ./mokctl.deploy create cluster
  [[ ${lines[0]} == "Usage: mokctl"* ]]
}

@test "Not enough options: 'mokctl create cluster name'" {
  run ./mokctl.deploy create cluster name
  [[ ${lines[0]} == "Usage: mokctl"* ]]
}

@test "Not enough options: 'mokctl create cluster name 1'" {
  run ./mokctl.deploy create cluster name 1
  [[ ${lines[0]} == "Usage: mokctl"* ]]
}

@test "Zero masters fail: 'mokctl create cluster name 0 0'" {
  run ./mokctl.deploy create cluster name 0 0
  [[ ${lines[0]} == "Usage: mokctl"* ]]
}

# vim:ft=bash:sw=2:et:ts=2:

```

Then I spent a long time trying to get [Unit Tests](https://en.wikipedia.org/wiki/Unit_testing) working but Bats isn't designed for that. It seems to be for [Black Box](https://en.wikipedia.org/wiki/Black-box_testing) testing only. Let's try something else...

### Install shUnit2

So for Unit Tests I found: [GitHub - kward/shunit2: shUnit2 is a xUnit based unit test framework for Bourne based shell scripts.](https://github.com/kward/shunit2) Another DuckDuckGo suggestion.

On Fedora it's installed with: `dnf install shunit2`, but once installed you copy a single file from `/usr/share/shunit2/shunit2` and add it to the project. Nice!

I got the unit tests working in no time with shUnit2 and I will probably get rid of Bats entirely. I have only done one test so far as Bats tired me out but here's the test:

```bash
#! /bin/sh
# file: examples/math_test.sh

testCreateValidClusterCommand() {
  parse_options create cluster mycluster 1 0
  assertTrue \
      "Valid command: 'mokctl create cluster name 1 0'" \
  "[[ $CREATE_CLUSTER_NAME == "mycluster" &&
     $CREATE_CLUSTER_NUM_MASTERS == "1" &&
     $CREATE_CLUSTER_NUM_WORKERS == "0" ]]"
}

oneTimeSetUp() {
  # Load include to test.
  . ./mokctl.deploy
}

# Load and run shUnit2.
. tests/shunit2

```

And, it's integrated in the Makefile, so we have:

* `make` - to build the `mokctl` command.

* `make install` - to install into `/usr/local/bin`.

* `make test` - to test the code.

and here's what the Makefile looks like now:

```bash
.PHONY: all install clean test unittest

all: mokctl.deploy

mokctl.deploy: mokctl mok-centos-7
    bash mokctl/embed-dockerfile.sh
    chmod +x mokctl.deploy

install:
    install mokctl.deploy /usr/local/bin/mokctl

clean:
    rm -f mokctl.deploy

test: clean mokctl.deploy unittest
    ./tests/test_mokctl.sh

unittest: mokctl.deploy
    ./tests/unit-tests.sh

# vim:noet:ts=2:sw=2

```

I'll finish off the tests so you can contribute if you want to but I won't give any more updates about this. It's all in the github repo, and won't really get any more complex than this.

> **Side Note**: About using shUnit2: To do unit tests, all the functions in the original script (in this case `mokctl`)  need to be copied into the shUnit2 execution space. This means that `exit` can't be called otherwise shUnit2 exits. I went through the code and replaced all my `exit` commands with `return`. Finally, instead of calling `exit` to set the script exit code use `return`. This will set the exit code of the script but won't exit shUnit2. This is a good programming habit anyway, especially when writing libraries, and when using shUnit2 the script is essentially run as a library. A few tips for writing testable shell scripts:
> 
> * Use functions for everything.
>   
>   They will not be run when using `source`.
> 
> * Have as little code as possible running outside of functions.
>   
>   Any code outside of functions will be run when using `source`. Have globals outside of functions initialsed to zero values. This way, each time the script is 'sourced', it will reset all the variables automatically.
> 
> * Don't use `exit` anywhere in the shell script.
>   
>   Only use `return X`, which is better practice anyway, but not as easy as `exit`. On the final `return X`,  when script execution ends, `X` will be the final exit code of the script.
> 
> * Start testing very early on in the project.
>   
>   Writing tests once the code is written is HARD. Already I have had to change the program to make testing work well. Imagine how hard it would be if it was a thousand lines long. [Test Driven Development](https://en.wikipedia.org/wiki/Test-driven_development), TDD, is probably the way to go and I will be using TDD for any more functions I write. TDD also helps to keep functions small and single-purpose.
> 
> * Constants can't be used.
>   
>   The tests will fail in strange ways if using constants, with `declare -r`. ShUnit2 runs each test in the same address space (it doesn't fork a new process). Our Bash script is sourced for each test and it tries to reset the constant (read-only) variables, which, is not allowed. To get around this I used `sed` to remove `declare -r` from the source. I did not want to lose constants and figured this was better than removing them altogether.
> 
> * Use the following code to ensure `main()` is only called when run from the command line. I put it at the end of the source code, and have `main()` close to the top as that's what drives the whole program and is the first function I would like to see when looking at the code.
> 
> ```bash
> if ([ "$0" = "$BASH_SOURCE" ] || ! [ -n "$BASH_SOURCE" ]);
> then
>   main "$@"
> fi
> ```

### All done!

Buried in about a thousand lines of code are the functions that actually do the work. The functions below are all indirectly called by `do_create`, `do_delete` and `do_build`, which are not shown here. Let's see what they look like:

```bash
# ---------------------------------------------------------------------------
create_docker_container() {
# ---------------------------------------------------------------------------
# Runs a new container with docker run.
# Args:
#   arg1 - name to use as the name and hostname.
#   arg2 - the label to write to the container.

  docker run --privileged \
      -v /sys/fs/cgroup:/sys/fs/cgroup:ro \
      -v /lib/modules:/lib/modules:ro \
      --tmpfs /run --tmpfs /tmp \
      --detach \
      --name $1 \
      --hostname $1 \
      --label $2 \
      local/$BASEIMAGENAME
}

# ---------------------------------------------------------------------------
delete_docker_container() {
# ---------------------------------------------------------------------------
# Stops and removes docker container.
# Args:
#   arg1 - docker id to delete

  docker stop $id || return $?
  docker rm $id || return $?
}

...

# ---------------------------------------------------------------------------
build_container_image() {
# ---------------------------------------------------------------------------
# Creates the docker build directory in $DOCKERBUILDTMPDIR then calls
# docker build to build the image.
# No args expected.

  create_docker_build_dir

  run_with_progress \
      "    Creating base image, '$BASEIMAGENAME'" \
      docker build -t "local/$BASEIMAGEAME" "$DOCKERBUILDTMPDIR/$BASEIMAGENAME"

  retval=$?
  [[ $retval -ne 0 ]] && {
    echo "ERROR: Docker returned an error, shown below"
    echo
    cat $RUNWITHPROGRESS_OUTPUT
    echo
    return $ERROR
  }

  return $retval
}

...

# ---------------------------------------------------------------------------
get_master_join_details(){
# ---------------------------------------------------------------------------
# 'docker exec' into the master to get CA hash, a token, and the master IP.
# The caller can eval the output of this function to set the variables:
# cahash, token, and masterip.
# Args:
#   arg1 - id/name of master container

  local joinvarsfile=`mktemp --tmpdir=/var/tmp`

  cat <<'EnD' >$joinvarsfile
#!/bin/bash
set -e
cahash=$(openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | \
        openssl rsa -pubin -outform der 2>/dev/null | \
        openssl dgst -sha256 -hex | sed 's/^.* //')
token=$(kubeadm token create --kubeconfig=/etc/kubernetes/admin.conf 2>/dev/null)
ip=$(ip ro get 8.8.8.8 | cut -d" " -f 7)
echo "cahash=$cahash"
echo "token=$token"
echo "masterip=$ip"
exit 0
EnD

  docker cp $joinvarsfile $1:/root/joinvars.sh || return $?
  rm -f $joinvarsfile

  docker exec $1 bash /root/joinvars.sh
}

...

# ---------------------------------------------------------------------------
set_up_master_node() {
# ---------------------------------------------------------------------------
# Use kubeadm to set up the master node.
# Args:
#   arg1 - the container to set up.

  local setupfile=`mktemp --tmpdir=/var/tmp`

  cat <<'EnD' >$setupfile
# Disable ipv6
sysctl -w net.ipv6.conf.all.disable_ipv6=1
sysctl -w net.ipv6.conf.default.disable_ipv6=1
# Run the preflight phase
kubeadm init \
  --ignore-preflight-errors Swap \
  phase preflight
# Set up the kubelet
kubeadm init phase kubelet-start
# Edit the kubelet configuration file
echo "failSwapOn: false" >>/var/lib/kubelet/config.yaml
# Tell kubeadm to carry on from here
kubeadm init \
  --pod-network-cidr=10.244.0.0/16 \
  --ignore-preflight-errors Swap \
  --skip-phases=preflight,kubelet-start
declare -i i=120
while [[ $((i--)) -gt 0 ]]; do
  curl -k https://localhost:6443/api/ && break
  sleep 1
done
export KUBECONFIG=/etc/kubernetes/admin.conf
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/2140ac876ef134e0ed5af15c65e414cf26827915/Documentation/kube-flannel.yml
EnD

  docker cp $setupfile $1:/root/setup.sh
  rm -f $setupfile

  docker exec $1 bash /root/setup.sh
}

...

# ---------------------------------------------------------------------------
set_up_worker_node() {
# ---------------------------------------------------------------------------
# Use kubeadm to set up the master node
# Args:
#   arg1 - the container to set up.

  local setupfile=`mktemp --tmpdir=/var/tmp`
  local cahash=$2 token=$3 masterip=$4

  cat <<EnD >$setupfile
# Wait for the master API to become ready
while true; do
  curl -k https://$masterip:6443/
  [[ \$? -eq 0 ]] && break
  sleep 1
done
# Do the preflight tests (ignoring swap error)
kubeadm join \
  phase preflight \
    --token $token \
      --discovery-token-ca-cert-hash sha256:$cahash \
        --ignore-preflight-errors Swap \
          $masterip:6443
# Set up the kubelet
kubeadm join \
  phase kubelet-start \
    --token $token \
      --discovery-token-ca-cert-hash sha256:$cahash \
        $masterip:6443 &
while true; do
  [[ -e /var/lib/kubelet/config.yaml ]] && break
    sleep 1
  done
# Edit the kubelet configuration file
echo "failSwapOn: false" >>/var/lib/kubelet/config.yaml
systemctl restart kubelet
EnD

  docker cp $setupfile $1:/root/setup.sh
  rm -f $setupfile

  docker exec $1 bash /root/setup.sh
}


```

Not too bad, and quite close to the original commands so it should be fairly easy to understand what's going on. Take a look at [the source](/mokctl/mokctl) to see the whole script.

> **Side Note**: Throughout the code I have used explicit and implicit return values to indicate success or failure to the calling function. If there is an error, I try to output the error and details as soon as possible then return an error status. This is the same way it is done when writing in Google Go (golang). 

## Trying it out

We'll do a complete end-to-end test, from cloning this repo, installing the software, creating a cluster then destroying it. Then we've got proper work to do fixing the performance problem - where we should learn a great deal.

### The End to End Experience

Install:

```bash
git clone https://github.com/mclarkson/my-own-kind.git
cd my-own-kind
sudo make install
```

Build the image:

```bash
mokctl build image
```

Create a cluster with one master and one worker:

```bash
mokctl create cluster mycluster 1 1
```

Get the full help text with `mokctl -h`, and also shorter command help, for example:

```bash
mokctl create -h
mokctl delete -h
mokctl build -h
mokctl get -h
```

Delete the cluster:

```bash
mokctl delete cluster mycluster
```

And finally to uninstall `mokctl`:

```bash
# In the my-own-kind top-level repository directory
make uninstall
```

That's it!

## What's Next?

[Testing and fixing](/docs/testfix.md).
