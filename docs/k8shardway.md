> **My Own Kind changes:**
> 
> This tutorial is a modified version of the original developed by [Kelsey Hightower](https://github.com/kelseyhightower/kubernetes-the-hard-way).
> While the original one uses GCP as the platform to deploy kubernetes, 
> we use My Own Kind's `mokctl` to deploy a cluster in containers on a local machine.
> 
> If you prefer the cloud version, refer to the original one [here](https://github.com/kelseyhightower/kubernetes-the-hard-way).
> 
> If you prefer the VirtualBox version, refer to Mumshad Mannambeth's one [here](https://github.com/mmumshad/kubernetes-the-hard-way)
> 
> We will try to keep as close to the original documentation as possible and use the same versions used in the original.

# Kubernetes The Hard Way

This tutorial walks you through setting up Kubernetes the hard way. This guide is not for people looking for a fully automated command to bring up a Kubernetes cluster. If that's you then check out [Google Kubernetes Engine](https://cloud.google.com/kubernetes-engine), or the [Getting Started Guides](https://kubernetes.io/docs/setup).

Kubernetes The Hard Way is optimized for learning, which means taking the long route to ensure you understand each task required to bootstrap a Kubernetes cluster.

> The results of this tutorial should not be viewed as production ready, and may receive limited support from the community, but don't let that stop you from learning!

## Copyright

<a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/"><img alt="Creative Commons License" style="border-width:0" src="https://i.creativecommons.org/l/by-nc-sa/4.0/88x31.png" /></a><br />This work is licensed under a <a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/">Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License</a>.

## Target Audience

The target audience for this tutorial is someone planning to support a production Kubernetes cluster and wants to understand how everything fits together.

## Cluster Details

Kubernetes The Hard Way guides you through bootstrapping a highly available Kubernetes cluster with end-to-end encryption between components and RBAC authentication.

* [kubernetes](https://github.com/kubernetes/kubernetes) 1.15.3
* [containerd](https://github.com/containerd/containerd) 1.2.9
* [coredns](https://github.com/coredns/coredns) v1.6.3
* [cni](https://github.com/containernetworking/cni) v0.7.1
* [etcd](https://github.com/coreos/etcd) v3.4.0

## Labs

This tutorial assumes you have access to `mokctl`. While `mokctl` is used for basic infrastructure requirements the lessons learned in this tutorial can be applied to other platforms.

* [Prerequisites](kubernetes-the-hard-way/01-prerequisites.md)
* [Installing the Client Tools](kubernetes-the-hard-way/02-client-tools.md)
* [Provisioning Compute Resources](kubernetes-the-hard-way/03-compute-resources.md)
* [Provisioning the CA and Generating TLS Certificates](kubernetes-the-hard-way/04-certificate-authority.md)
* [Generating Kubernetes Configuration Files for Authentication](kubernetes-the-hard-way/05-kubernetes-configuration-files.md)
* [Generating the Data Encryption Config and Key](kubernetes-the-hard-way/06-data-encryption-keys.md)
* [Bootstrapping the etcd Cluster](kubernetes-the-hard-way/07-bootstrapping-etcd.md)
* [Bootstrapping the Kubernetes Control Plane](kubernetes-the-hard-way/08-bootstrapping-kubernetes-controllers.md)
* [Bootstrapping the Kubernetes Worker Nodes](kubernetes-the-hard-way/09-bootstrapping-kubernetes-workers.md)
* [Configuring kubectl for Remote Access](kubernetes-the-hard-way/10-configuring-kubectl.md)
* [Provisioning Pod Network Routes](kubernetes-the-hard-way/11-pod-network-routes.md)
* [Deploying the DNS Cluster Add-on](kubernetes-the-hard-way/12-dns-addon.md)
* [Smoke Test](kubernetes-the-hard-way/13-smoke-test.md)
* [Cleaning Up](kubernetes-the-hard-way/14-cleanup.md)
