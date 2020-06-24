# Install mokctl on Linux

![](../docs/images/install-mokctl-linux.gif)

View the [screencast file](install-mokctl-linux.scr)

```bash
# How to install and use mokctl in mokbox
lsb_release -d
# Paste the alias line:
alias mokbox='docker run --rm -ti --hostname mokbox --name mokbox -v /var/run/docker.sock:/var/run/docker.sock -v /var/tmp:/var/tmp myownkind/mokbox'
# Add the alias to files such as ~/.bashrc or ~/.zshrc (not shown)
# And that's it .. You can use it right now! Let's use mokbox now...

# Log in to mokbox:
mokbox
# We're in!
# Build the base image:
mokctl build -h
mokctl build image --get-prebuilt-image
# Let's create a 7 node kubernetes cluster, this will take a couple minutes...
mokctl create -h
mokctl create cluster myk8s --with-lb --masters 3 --workers 3
export KUBECONFIG=/var/tmp/admin-myk8s.conf
# Kubectl is installed already in mokbox and the cluster should be fully ready
# Let's check the status:
kubectl get pods -A
# All running :)
kubectl get nodes
# 3 worker nodes - good. Only 1 master node!
# Master nodes are behind the load balancer so only show up as one node.
# Let's ask mokctl:
mokctl get -h
mokctl get cluster
# 7 nodes - good!

# Try starting a Pod:
kubectl run --rm -ti --restart=Never --image=alpine shell2 sh
ip address
apk add fortune
# 'apk add' downloads from the Internet, so networking and external dns looks ok
fortune
exit
# Now to delete the cluster we just made:
mokctl delete -h
mokctl delete cluster myk8s
y
mokctl get cluster
# All deleted
exit
# After exit the container we used is deleted since it has '--rm' in the alias
docker ps -a
# No containers
# Thanks for watching!
```
