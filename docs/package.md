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

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

</div>

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

Take a look at [my-own-kind/mok-centos-7](/mok-centos-7) now to see how the above commands have been added to the Dockerfile, and how the [Here Documents](https://en.wikipedia.org/wiki/Here_document) have been saved as files and added as COPY commands in the [Dockerfile](/mok-centos-7/Dockerfile).

It all looks quite simple and much cleaner. It took a couple of hours to get it looking that simple - at first it still looked messy, and there were many change-code/test -build iterations but it does no more and no less than before (except for downloading CNI binaries of course!).

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

Taken from [Build - [Install the kubernetes components with kubeadm](https://github.com/mclarkson/my-own-kind/blob/master/docs/build.md#install-the-kubernetes-components-with-kubeadm)](/docs/build.md#install-the-kubernetes-components-with-kubeadm).

Exec in:

```bash
docker exec -ti master-1 bash
```

Then copy and paste:

```bash
{
  # Run the preflight phase
  kubeadm init \
    --pod-network-cidr=10.244.0.0/16 \
    --ignore-preflight-errors Swap
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

Run the top 3 lines from the output, without `sudo`, like so:

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

There was no need to do the phased kubeadm join since it isn't granular enough anyway, so just the hack will do.

### Result

Success! It was alot easier than before but we have a show-stopper of a problem, where the `kubelet` uses way too much CPU.

To debug this problem it would probably help alot to be able to create and destroy clusters with one command.

## Scripted cluster creation and deletion

This can be accomplished with a simple shell script that will run the above commands for us. Note that we're not looking to create a fully fledged solution, just one that will make it quicker to try out fixes.

Looking at the above this is what we'll need for, ummm, `mokctl`:

1. The CLI interface:
   
   * `mokctl create cluster NAME NUM_MASTERS NUM_WORKERS`
   
   * `mokctl delete cluster NAME`

Let's code that now:

```bash
#!/usr/bin/env bash

# ---------------------------------------------------------------------------
# GLOBALS
# ---------------------------------------------------------------------------

STATE="COMMAND"
ERROR=1
OK=0

COMMAND=
SUBCOMMAND=

# Creating cluster vars
CREATE_CLUSTER_NAME=
NUM_MASTERS=
NUM_WORKERS=

# Deleting cluster vars
DELETE_CLUSTER_NAME=

# ---------------------------------------------------------------------------
main() {
# ---------------------------------------------------------------------------
# It all starts here

  parse_options "$@"

  case "$COMMAND" in
    create) do_create ;;
    delete) do_delete ;;
  esac
}

# ---------------------------------------------------------------------------
do_create() {
# ---------------------------------------------------------------------------

  case $SUBCOMMAND in
    cluster) do_create_cluster ;;
  esac
}

# ---------------------------------------------------------------------------
do_create_cluster() {
# ---------------------------------------------------------------------------

  if [[ -z $CREATE_CLUSTER_NAME ]]; then
    usage
    echo "Please provide the Cluster NAME to create."
    exit $ERROR
  fi

  if [[ -z $NUM_MASTERS ]]; then
    usage
    echo "Please provide the number of Masters to create."
    exit $ERROR
  fi

  if [[ -z $NUM_WORKERS ]]; then
    usage
    echo "Please provide the number of Workers to create."
    exit $ERROR
  fi

}

# ---------------------------------------------------------------------------
do_delete() {
# ---------------------------------------------------------------------------

  case $SUBCOMMAND in
    cluster) do_delete_cluster ;;
  esac
}

# ---------------------------------------------------------------------------
do_delete_cluster() {
# ---------------------------------------------------------------------------

  if [[ -z $DELETE_CLUSTER_NAME ]]; then
    usage
    echo "Please provide the Cluster NAME to delete."
    exit $ERROR
  fi
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

# ---------------------------------------------------------------------------
get_state() {
# ---------------------------------------------------------------------------
# Output the current state
# No args accepted

  echo "$STATE"
}

# ---------------------------------------------------------------------------
next_state() {
# ---------------------------------------------------------------------------
# Set the next valid state
# No args accepted

  case $STATE in
    COMMAND) STATE="SUBCOMMAND" ;;
    SUBCOMMAND) STATE="OPTION" ;;
    OPTION) STATE="OPTION" ;;
  esac
}

# ---------------------------------------------------------------------------
check_token_for_command_state() {
# ---------------------------------------------------------------------------
# Check for a valid token in start state
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
}

# ---------------------------------------------------------------------------
check_token_for_subcommand_state() {
# ---------------------------------------------------------------------------
# Check for a valid token in start state
# Args:
#   arg1 - token

  case $COMMAND in
    create) return `check_create_subcommand_token $1` ;;
    delete) return `check_delete_subcommand_token $1` ;;
  esac
}

# ---------------------------------------------------------------------------
check_create_subcommand_token() {
# ---------------------------------------------------------------------------
# Check for a valid token in start state
# Args:
#   arg1 - token

  case $1 in
    cluster) SUBCOMMAND=cluster
      ;;
    ?*) return $ERROR
      ;;
  esac

  return $OK
}

# ---------------------------------------------------------------------------
check_delete_subcommand_token() {
# ---------------------------------------------------------------------------
# Check for a valid token in start state
# Args:
#   arg1 - token

  case $1 in
    cluster) SUBCOMMAND=cluster
      ;;
    ?*) return $ERROR
      ;;
  esac
}

# ---------------------------------------------------------------------------
check_token_for_option_state() {
# ---------------------------------------------------------------------------
# Check for a valid token in start state
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
check_token_for_option2_state() {
# ---------------------------------------------------------------------------
# Check for a valid token in start state
# Args:
#   arg1 - token

  case $COMMAND in
    create)
      case $SUBCOMMAND in
        cluster) NUM_MASTERS="$1"
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
check_token_for_option3_state() {
# ---------------------------------------------------------------------------
# Check for a valid token in start state
# Args:
#   arg1 - token

  case $COMMAND in
    create)
      case $SUBCOMMAND in
        cluster) NUM_WORKERS="$1"
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
parse_options() {
# ---------------------------------------------------------------------------

  set -- "$@"
  local ARGN=$#
  while [ "$ARGN" -ne 0 ]
  do
    case $1 in
      -h) usage
          exit 0
      ;;
      ?*) case `get_state` in
            COMMAND) check_token_for_command_state $1
                   [[ $? -eq $ERROR ]] && {
                     usage
                     echo "Invalid COMMAND, '$1'."
                     echo
                     exit $ERROR
                   }
                   COMMAND="$1"
                   next_state
                 ;;
            SUBCOMMAND) check_token_for_subcommand_state $1
                   [[ $? -eq $ERROR ]] && {
                     usage
                     echo "Invalid SUBCOMMAND for $COMMAND, '$1'."
                     echo
                     exit $ERROR
                   }
                   SUBCOMMAND="$1"
                   next_state
                 ;;
            OPTION) check_token_for_option_state $1
                   [[ $? -eq $ERROR ]] && {
                     usage
                     echo "Invalid OPTION for $COMMAND $SUBCOMMAND, '$1'."
                     echo
                     exit $ERROR
                   }
                   next_state
                 ;;
            OPTION2) check_token_for_option2_state $1
                   [[ $? -eq $ERROR ]] && {
                     usage
                     echo "Invalid OPTION for $COMMAND $SUBCOMMAND, '$1'."
                     echo
                     exit $ERROR
                   }
                   next_state
                 ;;
            OPTION3) check_token_for_option3_state $1
                   [[ $? -eq $ERROR ]] && {
                     usage
                     echo "Invalid OPTION for $COMMAND $SUBCOMMAND, '$1'."
                     echo
                     exit $ERROR
                   }
                   next_state
                 ;;
            END) usage
                 echo -n "ERROR No more options expected, '$1' is unexpected"
                 echo " for '$COMMAND $SUBCOMMAND'"
                 exit $ERROR
                 ;;
            ?*) echo "Internal ERROR. Invalid state '`get_state`'"
                exit $ERROR
          esac
      ;;
    esac
    shift 1
    ARGN=$((ARGN-1))
  done
}

if ([ "$0" = "$BASH_SOURCE" ] || ! [ -n "$BASH_SOURCE" ]);
then
  main "$@"
fi

# vim:ft=bash:sw=2:et:ts=2:

```

This is a state machine implementation for Bash. I thought I would put the work in right now to code a simple state machine just in case I end up having to do a lot more with it. It's surprising how long scripts hang around, and indeed, kubernetes was initially a large set of shell scripts!

The code currently just makes sure that the correct sub-command and options are supplied for each command.

The work that we need doing will go into the two functions: `do_create_cluster()`, and `do_delete_cluster()`.

Let's code them now, and no surprises this time:

```

```
