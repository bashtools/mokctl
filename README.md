# My Own Kind

![](docs/images/mokctl-demo.gif)

## Summary

Build a conformant kubernetes cluster in containers, on Linux, using docker only, by hand, from scratch, for learning.

If you follow the instructions in this repository you will end up building your own version of [Kind](https://kind.sigs.k8s.io/). I'm pretty sure it won't be easy though - there's so much that can go wrong!

To get the most out of the "labs", and I use that term loosely, you should have some theoretical understanding of kubernetes. Some good resources are:

* [Certified Kubernetes Administrator (CKA) with Practice Exam Tests](https://www.udemy.com/course/certified-kubernetes-administrator-with-practice-tests/)
* [Kubernetes in Action by Marko Luksa](https://www.goodreads.com/book/show/34013922-kubernetes-in-action)

Send a Pull Request to add to this list.

## Status

In progress. `mokctl` is in a working state on Fedora 31.

Whether it will work on Mac/Windows is unkown.

## Let's get started

1. [Single Node](docs/build.md)
   
   Jump straight into setting up a docker container for a single node kubernetes cluster.

2. [Package](docs/package.md)
   
   We package up what we have learned ready for the next task.

3. [Testing and Fixing](/docs/testfix.md)
   
   This thing has bugs. Let's fix it.

4. [Kubernetes the Hard Way](/docs/k8shardway.md)
   
   The classic remade for MOK.

5. [Multi Node]()
   
   Build a bigger cluster using our package.

6. [Upgrade](/docs/upgrade.md)
   
   We can install any version of kubernetes. Let's try installing an older cluster and upgrading it.

7. [Add-ons](/docs/addons.md)
   
   Trying popluar kubernetes add-ons.

### Try mokctl

Probably the best way would be to:

```bash
git clone https://github.com/mclarkson/my-own-kind.git
cd my-own-kind
make test
sudo make install
mokctl build image
mokctl create cluster mycluster 1 0
```

Removal

```bash
# To remove mokctl
sudo make uninstall

# OR, to remove mokctl and the `~/.mok/` configuration directory
sudo make purge
```

Take note of the [Status](#status) above.

## Contributing

Please check the 'Help Wanted' issues if you fancy helping.

All types of contributions are welcome, from bug reports, success stories, feature requests, fixing typppos, to coding. Also check the [CONTRIBUTING.md](/CONTRIBUTING.md) document.

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

* To set up a full kubernetes cluster inside containers.
  
  So it works on my under-powered laptop.

* To use [cri-o](https://cri-o.io/) instead of docker/containerd.
  
  It looks like CRI-O is the future.

* To use [kubeadm](https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm/).
  
  To get a verifiably compliant kubernetes cluster running.
