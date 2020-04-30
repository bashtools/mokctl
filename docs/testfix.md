# Testing and Fixing

<!-- START doctoc -->

<!-- END doctoc -->

Previously I showed to different ways to ‘join’ a node to the cluster. I placed the second version, from the ‘Build’ lab, in the mokctl code and spent a couple hours trying to get it working. It wouldn't, work, so I went back to the first, phased, version and it worked straight away. I'm not sure why yet but we'll return to that later.

We have the new utility program, `mokctl`,  which builds new master and worker ‘nodes’. All the system pods start but a simple busybox pod does not. Not working:

```bash
kubectl run -ti --image busybox busybox sh
```

## Fixing Busybox not working

On CRI-O’s GitHub repository there is a page [Running CRI-O with kubeadm tutorial](https://github.com/cri-o/cri-o/blob/master/tutorials/kubeadm.md) provides some important information that I will check:

* In the `entrypoint` file, taken from Kind, there is a function, `fix_cgroup` that remaps cgroups by moving files and directories around in the `/sys/fs/cgroup` pseudo-filesystem. I copied bits of code from that and pasted directly into my system and found that this code is never run for us, so it seems that is for fixing old versions of docker. I'm not sure if this is relevant or not yet, but think not, as it's trying to recreate the original cgroup layout. Our cgroups look the same inside and outside of a container hence why I think this is not our problem.

* `/var/lib/kubelet/kubeadm-flags.env` should be: 
  
  ```none
  KUBELET_EXTRA_ARGS=--feature-gates="AllAlpha=false,RunAsGroup=true" --container-runtime=remote --cgroup-driver=systemd --container-runtime-endpoint=&#39;unix:///var/run/crio/crio.sock&#39; --runtime-request-timeout=5m
  ```

* The cri-o CNI in, `/etc/cni/net.d/100-crio-bridge.conf`, should have:
  
      ...
        "ranges": [
            [{ "subnet": "10.244.0.0/16" }]
        ]
      ...

* `/etc/crio/crio.conf` try:
  
      ...
      # Cgroup management implementation used for the runtime.
      cgroup_manager = "systemd"
      ...
  
  The ‘cgroup_manager’ setting here should match ‘--cgroup-driver’ in the `/var/lib/kubelet/kubeadm-flags.env` file above.

* There's some documentation in [kuberenetes.io/docs](https://kubernetes.io/docs/setup/production-environment/container-runtimes/#cri-o) that tells us how to install cri-o, but I get a 404, file not found, error when I try it, so we're probably doing it the right way, with:
  
        # The crio docs tell us that this is the way to do it
      
        CRIO_VERSION=1.17 # <- for kubernetes 1.17 - crio 1.18 is not available yet
        curl -L -o /etc/yum.repos.d/devel:kubic:libcontainers:stable.repo https://download.opensuse.org/repositories/devel:kubic:libcontainers:stable/CentOS_7/devel:kubic:libcontainers:stable.repo
        curl -L -o /etc/yum.repos.d/devel:kubic:libcontainers:stable:cri-o:$CRIO_VERSION.repo https://download.opensuse.org/repositories/devel:kubic:libcontainers:stable:cri-o:$CRIO_VERSION/CentOS_7/devel:kubic:libcontainers:stable:cri-o:$CRIO_VERSION.repo
      
        # Kubernetes needs the traffic control binary, tc.
        # You'll see an error in kubeadm later if 'tc' is not installed.
        yum -y install cri-o ...
  
  Which gets crio from downloads.opensuse.org. That's what cri-o said to do for RHEL/CentOS systems.
  
  ### Checking our system
  
  After building a kubernetes cluster with,
  
  ```bash
  mokctl create cluster badclust 1 2
  ```
  
  , I had a look at the system and it doesn't match the above. I made changes by hand by using `docker exec -ti badclust-worker-1` to enter into the worker container and made the above changes.
  
  I only changed one worker and left the other one. After the changes the Kubelet  on the edited worker consumed a great deal less CPU than the other non-edited worker. That was too easy! Let's code in those changes and see if it works.
  
  ### Changing the code
  
  #### entrypoint
  
  No need to touch.
  
  #### /var/lib/kubelet/kubeadm-flags.env
  
  I think Kubeadm creates this. Set up a single node cluster with `mokctl create cluster --skipmastersetup test 1 0` and exec in with `docker exec -ti test-master-1 bash`. 
  
  `rpm -qa | grep kube` shows all necessary kubernetes binaries installed, but the directory `/var/lib/kubelet does` not exist. Maybe Kubeadm writes it?
  
  From [Configuring each kubelet in your cluster using kubeadm - Kubernetes](https://v1-16.docs.kubernetes.io/docs/setup/production-environment/tools/kubeadm/kubelet-integration/#the-kubelet-drop-in-file-for-systemd):
  
  > ## The kubelet drop-in file for systemd
  > 
  > kubeadm ships with configuration for how systemd should run the kubelet.
  > Note that the kubeadm CLI command never touches this drop-in file.
  > 
  > This configuration file installed by the `kubeadm` [DEB](https://github.com/kubernetes/kubernetes/blob/master/build/debs/10-kubeadm.conf) or [RPM package](https://github.com/kubernetes/kubernetes/blob/master/build/rpms/10-kubeadm.conf) is written to `/etc/systemd/system/kubelet.service.d/10-kubeadm.conf` and is used by systemd.
  > It augments the basic [`kubelet.service` for RPM](https://github.com/kubernetes/kubernetes/blob/master/build/rpms/kubelet.service) (resp. [`kubelet.service` for DEB](https://github.com/kubernetes/kubernetes/blob/master/build/debs/kubelet.service))):
  > 
  > ```none
  > [Service]
  > Environment="KUBELET_KUBECONFIG_ARGS=--bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf
  > --kubeconfig=/etc/kubernetes/kubelet.conf"
  > Environment="KUBELET_CONFIG_ARGS=--config=/var/lib/kubelet/config.yaml"
  > # This is a file that "kubeadm init" and "kubeadm join" generate at runtime, populating
  > the KUBELET_KUBEADM_ARGS variable dynamically
  > EnvironmentFile=-/var/lib/kubelet/kubeadm-flags.env
  > # This is a file that the user can use for overrides of the kubelet args as a last resort. Preferably,
  > #the user should use the .NodeRegistration.KubeletExtraArgs object in the configuration files instead.
  > # KUBELET_EXTRA_ARGS should be sourced from this file.
  > EnvironmentFile=-/etc/default/kubelet
  > ExecStart=
  > ExecStart=/usr/bin/kubelet $KUBELET_KUBECONFIG_ARGS $KUBELET_CONFIG_ARGS $KUBELET_KUBEADM_ARGS $KUBELET_EXTRA_ARGS
  > ```
  > 
  > This file specifies the default locations for all of the files managed by kubeadm for the kubelet.
  > 
  > - The KubeConfig file to use for the TLS Bootstrap is `/etc/kubernetes/bootstrap-kubelet.conf`,
  >   but it is only used if `/etc/kubernetes/kubelet.conf` does not exist.
  > - The KubeConfig file with the unique kubelet identity is `/etc/kubernetes/kubelet.conf`.
  > - The file containing the kubelet’s ComponentConfig is `/var/lib/kubelet/config.yaml`.
  > - The dynamic environment file that contains `KUBELET_KUBEADM_ARGS` is sourced from `/var/lib/kubelet/kubeadm-flags.env`.
  > - **The file that can contain user-specified flag overrides with `KUBELET_EXTRA_ARGS` is sourced from `/etc/default/kubelet` (for DEBs), or `/etc/sysconfig/kubelet` (for RPMs). `KUBELET_EXTRA_ARGS` is last in the flag chain and has the highest priority in the event of conflicting settings.**
  
  The last bullet point shows where we should add that line. We're using CentOS (RPMs) so it's `/etc/sysconfig/kubelet`, and indeed, the file is there continaining just `KUBELET_EXTRA_ARGS=`.
  
  If we add that file it will be overwritten by `yum whatprovides /etc/sysconfig/kubelet`, which is the `kubelet-<version>` rpm. So we need to change that file in the Dockerfile or `mokctl`, in the function, ‘set_up_master_node()’ and ‘set_up_worker_node()’.
  
  I added the new config to the Dockerfile using COPY, and added the two files to the mok-centos-7 directory. 
  
  #### /etc/cni/net.d/100-crio-bridge.conf
  
  `yum whatprovides /etc/cni/net.d/100-crio-bridge.conf` is written when cri-o is installed. I edited the file, '100-crio-bridge.conf' that is already in the `mok-centos-7` directory.
  
  #### /etc/crio/crio.conf
  
  Doing `grep cgroup_manager /etc/crio/crio.conf` produces: `group_manager = "cgroupfs"`. So this also needs changing. This was already changed in the Dockerfile to ’cgroupfs’, as I thought it was the correct setting. I will change it to ‘systemd’.

### Trying the changes

```bash
  # Let's delete that test cluster
  mokctl delete cluster test

  # We made changes to dockerfile so rebuild the docker image
  # First update mokctl with the new dockerfiles
  # `cd` into the top level my-own-kind directory then
  sudo make install

  # Then rebuild the image (it will take a few minutes)
  mokctl build image

  # A four node cluster made my laptop unhappy last time so
  # lets try that again
  mokctl create cluster hope 1 3
```

### Result

* I had not deleted the cluster and the Kubelet timed out waiting for the Kube-apiserver to start.

* Deleted all clusters

* Trying again

* It still didn't work

* I tested cri-o using [Test cri-o](/docs/build.md#test-cri-o) - that worked so crio is ok.

* `/etc/sysconfig/kubelet` has our changes, but they are not in `/var/lib/kubelet/kubeadm-flags.env`, however `ps` shows:
  
      [root@hope-master-1 /]# ps axwwww | grep kubelet
         2173 ?        Ssl    0:00 /usr/bin/kubelet --bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc/kubernetes/kubelet.conf --config=/var/lib/kubelet/config.yaml --container-runtime=remote --container-runtime-endpoint=/var/run/crio/crio.sock --feature-gates=AllAlpha=false,RunAsGroup=true --container-runtime=remote --cgroup-driver=systemd --container-runtime-endpoint=unix:///var/run/crio/crio.sock --runtime-request-timeout=5m
  
  which is correct. Trying without the 'unix:///' prefix. (edit file then restart kubelet)
  
  It told me the format I'm using is deprecated so changing back.

* Tried removing the Alpha settings. No change

* Changed `/etc/sysconfig/kubelet` and `/etc/crio/crio.conf` to use cgroupfs

* Worked!

* Putting alpha bits back

* Still works

So, I've changed those two settings in the Dockerfiles and rebuilt the docker image again. Now to try that four node cluster.

It works and I can still use my laptop without noticing any slow-down, unlike the last time.

Now to try the busybox container:

```bash
kubectl run -ti --image busybox busybox sh
```

It failed again. Saying: `... failed to get network JSON for pod sandbox ...`

```bash
vi /etc/cni/net.d/10* -o
# change both files to version 0.3.1
```

Worked. I'm not sure what to do here because it's the flannel version that needs changing to 0.3.1 in the 10-flannel.conflist file.

Checking versions I see that I'm installing flannel as per the kubernetes docs and [those instructions have been removed](https://github.com/kubernetes/website/commit/f73647531dcdade2327412253a5f839781d57897/)

CoreOS, who wrote Flannel, say, for Kubernetes V1.17+ to use:

```bash
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
```

For, MOK this is run in `set_up_master_nodes` in `mokctl`. Changing and retrying... No need to rebuild the image this time.

#### All working at last!

Running busybox worked first time. My system is OK. The following screenshot says it all:

![](images/firsttimeworkingok.png)

## Checking against Kind

The CPU usage still seems quite high. Let's compare to Kind.

## What's next
