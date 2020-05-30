# Frequently Asked Questions

## What Kubernetes components are installed?

* Kubernetes core components:
  
  * kube-apiserver
  
  * kube-scheduler
  
  * kube-controller-manager
  
  * kube-proxy
  
  * core-dns
  
  * etcd
  
  * kubelet
  
  * kubeadm

* CNI Networking
  
  * Weave

* CRI Runtime
  
  * runc
    
    * crictl is also installed

Kubernetes is installed in CentOS 7 containers.

Kubeadm installs the components using RPMs and SystemD.

## Why Bash?

A question that keeps being asked is 'Why Bash?'.

Bash is a great tool for automating commands. In `mokctl`, Bash is a wrapper around podman or docker - that's it. Bash is perfect for this.

Bash can be a great tool for Rapid Application Development and for Proof of Concepts. Kubernetes started [more or less] this way - small Go applications and lots of Bash glue code. The `mokctl` code, working out how to do it, and all the documentation was written in 9 days. That's from zero to fully working application in 9 days - and 19 GitHub stars (which is a real motivator actually!) - in 9 days. That would be difficult to do in Python, Go, Java, Haskell, or whatever.

Why was it so fast to write? Well, whilst investigating how to create a kubernetes cluster in containers I copied and pasted all the commands in a Markdown document. Then the list of commands were pasted, as-is, into functions so I knew they would work. Doing this in another language would actually be alot more work. You can see that process in action in [Packaging](/docs/package.md).

Bash code from 10 years ago still works now. There aren't many languages that can do that, so I can be sure that code I have written will not be deprecated any time soon. Indeed Bash can still run the original Bourne shell (sh) code. If you didn't know, Bash is an acronym for Bourne Again SHell.

Bash is something every sysadmin knows. So for sysadmin tools it makes sense.

Later, in another document, I will show how a Bash program can be wrapped in a pretty GUI, using Go (golang) and a Javascript Framework to create a solid and maintainable user application.
