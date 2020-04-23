# My Own Kind

## Summary

My Own Kind - Build a conformant kubernetes cluster in containers, on Linux, using docker only, by hand, from scratch, for learning.

If you follow the instructions in this repository you will end up building your own Kind. I'm pretty sure it won't be easy though - there's so much that can go wrong!

To get the most out of the labs you should have a good overall understanding of kubernetes. Some good resources are:

* [Certified Kubernetes Administrator (CKA) with Practice Exam Tests](https://www.udemy.com/course/certified-kubernetes-administrator-with-practice-tests/)
* [Kubernetes in Action by Marko Luksa](https://www.goodreads.com/book/show/34013922-kubernetes-in-action)

Send a Pull Request to add to this list.

## Let's get started

1. [Single Node](docs/build.md)
   Jump straight into setting up a docker container for a single node kubernetes cluster.

2. [Package](docs/package.md)
   We package up what we have learned ready for the next task.

3. [Multi Node]()
   Build a bigger cluster using our package.

4. [Upgrade]()
   We can install any version of kubernetes. Let's try installing an older cluster and upgrading it. Not much hand-holding here though.

## License

Apache 2 - You can do what you like with the software, as long as you include the required notices. This permissive license contains a patent license 
from the contributors of the code. See: [tl;drLegal](https://tldrlegal.com/license/apache-license-2.0-%28apache-2.0%29) for a summary. Full text is in the LICENSE file.

## Why?

I started this project to improve my understanding of [kubernetes](https://kubernetes.io/), and to help me pass the [Certified Kubernetes Administrator](https://www.cncf.io/certification/cka/) exam. It's an amalgamation of information gleaned from:

* The kubernetes local container installer, [Kind](https://kind.sigs.k8s.io/).
* The official Kubernetes documentation at [kubernetes.io/docs/.../install-kubeadm/](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/).
* Mumshad Mannambeth's [kubernetes-the-hard-way](https://github.com/mmumshad/kubernetes-the-hard-way) - using VirtualBox.
  I also took his course on Udemy, [Certified Kubernetes Administrator (CKA) with Practice Exam Tests](https://www.udemy.com/course/certified-kubernetes-administrator-with-practice-tests/), which I highly recommended if you're new to kubernetes.
* Kelsey Hightower's [kubernetes-the-hard-way](https://github.com/kelseyhightower/kubernetes-the-hard-way) - using GCP. Check out the number of stars on this project!
* Other official sources (all shown).

I wanted something quite particular to my own needs/wants:

* To set up a kubernetes cluster on my under-powered laptop.
  My laptop is small and light with no internal fans. This means it's also not particularly powerful and it only has 8GB of RAM. Running Mumshad's kubernetes-the-hard-way has not been possible on my machine.
  I use Fedora and Gnome, and have done so for years since moving from Debian. I changed to Fedora at that time to be able to use the latest Gnome and found it so stable and easy to set up that I never went back to Debian. So, this document is **meant specifically for Fedora**, but any modern Linux should be fine.

* To set up a full kubernetes cluster inside containers.
  The Kind project builds kubernetes nodes as containers. Containers are native on Linux, unlike Mac and Windows, and so use very little resources. I can have a 3-node kind cluster running on my laptop with ease.

* To use [cri-o](https://cri-o.io/) instead of docker.
  CRI-O is a **C**ontainer **R**untime **I**nterface that is **O**CI Compliant. This follows Unix philosophy well, where a program is supposed to do one thing, and do that one thing well. All the things that docker does do have been broken out into individual parts and cri-o is one part created specifically for kubernetes. It starts and manages containers. It doesn't build images, or set up volumes, or networking.`kind` uses containerd but cri-o is used here instead.

* To use [kubeadm](https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm/).
  Ah, so this is not the Hard Way! I managed to do most of kubernetes-the-hard-way, using VirtualBox, which I recommend, but I could not play properly due to memory and CPU contstraints. It's important to install kubernetes the Kubeadm way too, as this is how a production cluster should be set up. After doing this the techniques can be used to build production ready clusters on AWS, GCP, Bare Metal, or on Developers laptops. The whole process will be understood from the ground up allowing great tools to be made. More importantly, this set up will be [a verified kubernetes conformant cluster](https://www.cncf.io/certification/software-conformance/).

So, basically, I want to create **my own Kind**. Then it will be packaged and made easy to install any version of kubernetes safe in the knowledge that key parts of its inner workings are understood.

I hope you have fun with it!
