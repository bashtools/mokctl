>  **Kubernetes the Hard Way using My Own Kind**
> 
> View a [screencast and transcript](/cmdline-player/kthw-4.md)

# Provisioning a CA and Generating TLS Certificates

In this lab you will provision a [PKI Infrastructure](https://en.wikipedia.org/wiki/Public_key_infrastructure) using CloudFlare's PKI toolkit, [cfssl](https://github.com/cloudflare/cfssl), then use it to bootstrap a Certificate Authority, and generate TLS certificates for the following components: etcd, kube-apiserver, kube-controller-manager, kube-scheduler, kubelet, and kube-proxy.

## Certificate Authority

In this section you will provision a Certificate Authority that can be used to generate additional TLS certificates.

First 'log in' to the podman container that we created earlier:

```
podman exec -ti kthw bash
```

Change to the `/certs` directory, which is volume mounted to the host:

```
cd /certs
```

Generate the CA configuration file, certificate, and private key:

```
{
cat > ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "8760h"
    },
    "profiles": {
      "kubernetes": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "8760h"
      }
    }
  }
}
EOF
cat > ca-csr.json <<EOF
{
  "CN": "Kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "CA",
      "ST": "Oregon"
    }
  ]
}
EOF
cfssl gencert -initca ca-csr.json | cfssljson -bare ca
}
```

View the created certificates
```
ls -lh *.pem
```

Results:

```
ca-key.pem
ca.pem
```
## Client and Server Certificates

In this section you will generate client and server certificates for each Kubernetes component and a client certificate for the Kubernetes `admin` user.

### The Admin Client Certificate

Generate the `admin` client certificate and private key:

```
{
cat > admin-csr.json <<EOF
{
  "CN": "admin",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:masters",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  admin-csr.json | cfssljson -bare admin
}
```

View the created certificates

```
ls -lh *.pem
```

Results:

```
admin-key.pem
admin.pem
```
### The Kubelet Client Certificates

Kubernetes uses a [special-purpose authorization mode](https://kubernetes.io/docs/admin/authorization/node/) called Node Authorizer, that specifically authorizes API requests made by [Kubelets](https://kubernetes.io/docs/concepts/overview/components/#kubelet). In order to be authorized by the Node Authorizer, Kubelets must use a credential that identifies them as being in the `system:nodes` group, with a username of `system:node:<nodeName>`. In this section you will create a certificate for each Kubernetes worker node that meets the Node Authorizer requirements.

Get the list of 'nodes' from `mokctl`:

```
exit
sudo mokctl get clusters | tee kthw-certs/cluster-list.txt
podman exec -ti kthw bash
```

Check that the file was created:

```
cat /certs/cluster-list.txt
```
Change to the `/certs` directory, which is volume mounted to the host:

```
cd /certs
```

Generate a certificate and private key for each Kubernetes worker node:

```
for instance in kthw-worker-1 kthw-worker-2 kthw-worker-3; do
cat > ${instance}-csr.json <<EOF
{
  "CN": "system:node:${instance}",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:nodes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF
INTERNAL_IP=$(grep ${instance} /certs/cluster-list.txt | awk '{ print $NF; }')
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=${instance},${INTERNAL_IP} \
  -profile=kubernetes \
  ${instance}-csr.json | cfssljson -bare ${instance}
done
```

View the created certificates

```
ls -lh *.pem
```

Results:

```
worker-0-key.pem
worker-0.pem
worker-1-key.pem
worker-1.pem
worker-2-key.pem
worker-2.pem
```

### The Controller Manager Client Certificate

Generate the `kube-controller-manager` client certificate and private key:

```
{
cat > kube-controller-manager-csr.json <<EOF
{
  "CN": "system:kube-controller-manager",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:kube-controller-manager",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-controller-manager-csr.json | cfssljson -bare kube-controller-manager
}
```

View the created certificates

```
ls -lh *.pem
```
Results:

```
kube-controller-manager-key.pem
kube-controller-manager.pem
```

### The Kube Proxy Client Certificate

Generate the `kube-proxy` client certificate and private key:

```
{
cat > kube-proxy-csr.json <<EOF
{
  "CN": "system:kube-proxy",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:node-proxier",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-proxy-csr.json | cfssljson -bare kube-proxy
}
```
View the created certificates

```
ls -lh *.pem
```

Results:

```
kube-proxy-key.pem
kube-proxy.pem
```
### The Scheduler Client Certificate

Generate the `kube-scheduler` client certificate and private key:

```
{
cat > kube-scheduler-csr.json <<EOF
{
  "CN": "system:kube-scheduler",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:kube-scheduler",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-scheduler-csr.json | cfssljson -bare kube-scheduler
}
```

View the created certificates

```
ls -lh *.pem
```

Results:

```
kube-scheduler-key.pem
kube-scheduler.pem
```

### The Kubernetes API Server Certificate

The `kubernetes-the-hard-way` IP addresses will be included in the list of subject alternative names for the Kubernetes API Server certificate. This will ensure the certificate can be validated by remote clients.

First set the variables used in the certificate:

```
KUBERNETES_PUBLIC_ADDRESS=$(grep kthw-lb /certs/cluster-list.txt | awk '{ print $NF; }')
echo $KUBERNETES_PUBLIC_ADDRESS
MASTER1=$(grep kthw-master-1 /certs/cluster-list.txt | awk '{ print $NF; }')
echo $MASTER1
MASTER2=$(grep kthw-master-2 /certs/cluster-list.txt | awk '{ print $NF; }')
echo $MASTER2
MASTER3=$(grep kthw-master-3 /certs/cluster-list.txt | awk '{ print $NF; }')
echo $MASTER3
```

Generate the Kubernetes API Server certificate and private key:

```
{
KUBERNETES_HOSTNAMES=kubernetes,kubernetes.default,kubernetes.default.svc,kubernetes.default.svc.cluster,kubernetes.svc.cluster.local
cat > kubernetes-csr.json <<EOF
{
  "CN": "kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=10.32.0.1,$MASTER1,$MASTER2,$MASTER3,${KUBERNETES_PUBLIC_ADDRESS},127.0.0.1,${KUBERNETES_HOSTNAMES} \
  -profile=kubernetes \
  kubernetes-csr.json | cfssljson -bare kubernetes
}
```

> The Kubernetes API server is automatically assigned the `kubernetes` internal dns name, which will be linked to the first IP address (`10.32.0.1`) from the address range (`10.32.0.0/24`) reserved for internal cluster services during the [control plane bootstrapping](08-bootstrapping-kubernetes-controllers.md#configure-the-kubernetes-api-server) lab.

Check the 'Subject Alternative' field, which should match the `--hostname` line above:
```
openssl x509 -noout -in kubernetes.pem -text | grep "Subject Alt" -A 1
```

View the created certificates

```
ls -lh *.pem
```
Results:

```
kubernetes-key.pem
kubernetes.pem
```

## The Service Account Key Pair

The Kubernetes Controller Manager leverages a key pair to generate and sign service account tokens as described in the [managing service accounts](https://kubernetes.io/docs/admin/service-accounts-admin/) documentation.

Generate the `service-account` certificate and private key:

```
{
cat > service-account-csr.json <<EOF
{
  "CN": "service-accounts",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  service-account-csr.json | cfssljson -bare service-account
}
```

View the created certificates

```
ls -lh *.pem
```

Results:

```
service-account-key.pem
service-account.pem
```

## Distribute the Client and Server Certificates

Copy the appropriate certificates and private keys to each worker instance:

Log out of the container to copy the files from the host:

```
exit
```

Check that all the certs are on the host:

```
ls kthw-certs
```

Change to the `kthw-certs` directory:

```
cd kthw-certs
```

Copy the appropriate certificates and private keys to each worker instance:

```
for instance in kthw-worker-1 kthw-worker-2 kthw-worker-3; do
  sudo podman cp ca.pem ${instance}:/root
  sudo podman cp ${instance}-key.pem ${instance}:/root
  sudo podman cp ${instance}.pem ${instance}:/root
done
```

Copy the appropriate certificates and private keys to each controller instance:

```
for instance in kthw-master-1 kthw-master-2 kthw-master-3; do
  sudo podman cp ca.pem ${instance}:/root
  sudo podman cp ca-key.pem ${instance}:/root
  sudo podman cp kubernetes-key.pem ${instance}:/root
  sudo podman cp kubernetes.pem ${instance}:/root
  sudo podman cp service-account-key.pem ${instance}:/root
  sudo podman cp service-account.pem ${instance}:/root
done
```
> The `kube-proxy`, `kube-controller-manager`, `kube-scheduler`, and `kubelet` client certificates will be used to generate client authentication configuration files in the next lab.

Next: [Generating Kubernetes Configuration Files for Authentication](05-kubernetes-configuration-files.md)
