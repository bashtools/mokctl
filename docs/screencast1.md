# Screencast 1

```
git clone https://github.com/mclarkson/my-own-kind.git
cd my-own-kind
make test
sudo make install

mokctl build
mokctl build image

mokctl get -h
mokctl get clusters

mokctl create
# Don't set up the containers!
mokctl create cluster test1 --skipmastersetup 1 1

export KUBECONFIG=~/.mok/admin.conf
# This won't work as containers weren't set up
kubectl get pods -A
mokctl get cluster
docker exec -ti test1-master-1 bash
ps axf
rpm -qa | grep kube
# Do kubernetes-the-hard-way now :)
exit
mokctl delete cluster test1

# This will take a few minutes!
mokctl create cluster test1 1 2
docker ps
kubectl get pods -A
kubectl get nodes

kubectl run -ti --image busybox busybox sh

ping 8.8.8.8
exit
mokctl get cluster

mokctl delete cluster test1
sudo make uninstall
cd ..
rm -rf my-own-kind
# Thanks for watching!
```
