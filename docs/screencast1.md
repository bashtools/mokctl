# Screencast 1

```
git clone https://github.com/mclarkson/my-own-kind.git
cd my-own-kind
make test
sudo make install

mokctl --help 
mokctl build
mokctl build image

mokctl get -h
mokctl get clusters

mokctl create -h
mokctl create cluster test1 --skipmastersetup 1 1

export KUBECONFIG=~/.mok/admin.conf
kubectl get pods -A
kubectl get nodes
mokctl delete cluster test1

This will take a few minutes!
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
Thanks for watching!
```
