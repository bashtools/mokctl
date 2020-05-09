## Why?

I started this project to improve my understanding of [kubernetes](https://kubernetes.io/), and to help me pass the [Certified Kubernetes Administrator](https://www.cncf.io/certification/cka/) exam. It's an amalgamation of information gleaned from:

- The kubernetes local container installer, [Kind](https://kind.sigs.k8s.io/).
- The official Kubernetes documentation at [kubernetes.io/docs/.../install-kubeadm/](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/).
- Mumshad Mannambeth's [kubernetes-the-hard-way](https://github.com/mmumshad/kubernetes-the-hard-way) - using VirtualBox.
  I also took his course on Udemy, [Certified Kubernetes Administrator (CKA) with Practice Exam Tests](https://www.udemy.com/course/certified-kubernetes-administrator-with-practice-tests/), which I highly recommended if you're new to kubernetes.
- Kelsey Hightower's [kubernetes-the-hard-way](https://github.com/kelseyhightower/kubernetes-the-hard-way) - using GCP. Check out the number of stars on this project!
- Other official sources (all shown).

I wanted something quite particular to my own needs/wants:

- To set up a full kubernetes cluster inside containers.
  
  So it works on my under-powered laptop.

- To use [cri-o](https://cri-o.io/) instead of docker/containerd.
  
  It looks like CRI-O is the future.

- To use [kubeadm](https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm/).
  
  To get a verifiably compliant kubernetes cluster running.
