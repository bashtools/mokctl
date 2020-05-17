# KTHW 04 Provisioning a CA and Generating TLS Certificates

![](../docs/images/kthw-4.gif)

View the [screencast file](../cmdline-player/kthw-4.scr)

```bash
.MD >  **Kubernetes the Hard Way using My Own Kind**
.MD > 
.MD > View a [screencast and transcript](/cmdline-player/kthw-4.md)
.MD 
.MD # Provisioning a CA and Generating TLS Certificates
.MD 
.MD In this lab you will provision a [PKI Infrastructure](https://en.wikipedia.org/wiki/Public_key_infrastructure) using CloudFlare's PKI toolkit, [cfssl](https://github.com/cloudflare/cfssl), then use it to bootstrap a Certificate Authority, and generate TLS certificates for the following components: etcd, kube-apiserver, kube-controller-manager, kube-scheduler, kubelet, and kube-proxy.
.MD 
# ---------------------------------------------------------
# Kubernetes the Hard Way - using `mokctl` from My Own Kind
# ---------------------------------------------------------
# 04-certificate-authority
# Create all the required certificates

.MD ## Certificate Authority
.MD 
.MD In this section you will provision a Certificate Authority that can be used to generate additional TLS certificates.
.MD 
# We need to log back into the podman container, 'kthw' then
# paste the command blocks

.MD First 'log in' to the podman container that we created earlier:
.MD
.MD ```
podman exec -ti kthw bash
.MD ```

# Creating the certificate authority (CA)

.MD 
.MD Change to the `/certs` directory, which is volume mounted to the host:
.MD
.MD ```
cd /certs
.MD ```
.MD
.MD Generate the CA configuration file, certificate, and private key:
.MD
.MD ```
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
.MD ```
.MD
.MD View the created certificates
.MD ```
ls -lh *.pem
.MD ```
.MD
.MD Results:
.MD 
.MD ```
.MD ca-key.pem
.MD ca.pem
.MD ```

.MD ## Client and Server Certificates
.MD 
.MD In this section you will generate client and server certificates for each Kubernetes component and a client certificate for the Kubernetes `admin` user.
.MD 
.MD ### The Admin Client Certificate
.MD 
.MD Generate the `admin` client certificate and private key:
.MD 
.MD ```
# Client and Server Certificates
# The Admin Client Certificate
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
.MD ```
.MD
.MD View the created certificates
.MD
.MD ```
ls -lh *.pem
.MD ```
.MD
.MD Results:
.MD 
.MD ```
.MD admin-key.pem
.MD admin.pem
.MD ```

.MD ### The Kubelet Client Certificates
.MD 
.MD Kubernetes uses a [special-purpose authorization mode](https://kubernetes.io/docs/admin/authorization/node/) called Node Authorizer, that specifically authorizes API requests made by [Kubelets](https://kubernetes.io/docs/concepts/overview/components/#kubelet). In order to be authorized by the Node Authorizer, Kubelets must use a credential that identifies them as being in the `system:nodes` group, with a username of `system:node:<nodeName>`. In this section you will create a certificate for each Kubernetes worker node that meets the Node Authorizer requirements.
.MD 
# The Kubelet Client Certificates

# First we'll log out of this container, get the list of IPs from
# `mokctl` and save them in the volume mount, then log back in
# and carry on creating certs.
.MD Get the list of 'nodes' from `mokctl`:
.MD
.MD ```
exit
sudo mokctl get clusters | tee kthw-certs/cluster-list.txt
podman exec -ti kthw bash
.MD ```
.MD
.MD Check that the file was created:
.MD
.MD ```
# We're back in. Is the file created?
cat /certs/cluster-list.txt
.MD ```
# Yes! good.
# Now to create the client certs
.MD Change to the `/certs` directory, which is volume mounted to the host:
.MD 
.MD ```
cd /certs
.MD ```
.MD
.MD Generate a certificate and private key for each Kubernetes worker node:
.MD
.MD ```
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
.MD ```
.MD
.MD View the created certificates
.MD
.MD ```
ls -lh *.pem
.MD ```
.MD
.MD Results:
.MD 
.MD ```
.MD worker-0-key.pem
.MD worker-0.pem
.MD worker-1-key.pem
.MD worker-1.pem
.MD worker-2-key.pem
.MD worker-2.pem
.MD ```
.MD
.MD ### The Controller Manager Client Certificate
.MD 
.MD Generate the `kube-controller-manager` client certificate and private key:
.MD 
.MD ```
# The Controller Manager Client Certificate

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
.MD ```
.MD
.MD View the created certificates
.MD
.MD ```
ls -lh *.pem
.MD ```
.MD Results:
.MD 
.MD ```
.MD kube-controller-manager-key.pem
.MD kube-controller-manager.pem
.MD ```
.MD 
.MD ### The Kube Proxy Client Certificate
.MD 
.MD Generate the `kube-proxy` client certificate and private key:
.MD 
.MD ```

# The Kube Proxy Client Certificate

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
.MD ```
.MD View the created certificates
.MD
.MD ```
ls -lh *.pem
.MD ```
.MD
.MD Results:
.MD 
.MD ```
.MD kube-proxy-key.pem
.MD kube-proxy.pem
.MD ```
.MD ### The Scheduler Client Certificate
.MD 
.MD Generate the `kube-scheduler` client certificate and private key:
.MD 
.MD ```

# The Scheduler Client Certificate

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
.MD ```
.MD
.MD View the created certificates
.MD
.MD ```
ls -lh *.pem
.MD ```
.MD
.MD Results:
.MD 
.MD ```
.MD kube-scheduler-key.pem
.MD kube-scheduler.pem
.MD ```
.MD 
.MD ### The Kubernetes API Server Certificate
.MD 
.MD The `kubernetes-the-hard-way` IP addresses will be included in the list of subject alternative names for the Kubernetes API Server certificate. This will ensure the certificate can be validated by remote clients.
.MD 
.MD First set the variables used in the certificate:
.MD
.MD ```

# The Kubernetes API Server Certificate

KUBERNETES_PUBLIC_ADDRESS=$(grep kthw-lb /certs/cluster-list.txt | awk '{ print $NF; }')
echo $KUBERNETES_PUBLIC_ADDRESS
MASTER1=$(grep kthw-master-1 /certs/cluster-list.txt | awk '{ print $NF; }')
echo $MASTER1
MASTER2=$(grep kthw-master-2 /certs/cluster-list.txt | awk '{ print $NF; }')
echo $MASTER2
MASTER3=$(grep kthw-master-3 /certs/cluster-list.txt | awk '{ print $NF; }')
echo $MASTER3
.MD ```
.MD
.MD Generate the Kubernetes API Server certificate and private key:
.MD 
.MD ```

# Create the certificate

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
  -hostname=10.88.0.1,$MASTER1,$MASTER2,$MASTER3,${KUBERNETES_PUBLIC_ADDRESS},127.0.0.1,${KUBERNETES_HOSTNAMES} \
  -profile=kubernetes \
  kubernetes-csr.json | cfssljson -bare kubernetes

}
.MD ```
.MD
.MD > The Kubernetes API server is automatically assigned the `kubernetes` internal dns name, which will be linked to the first IP address (`10.32.0.1`) from the address range (`10.32.0.0/24`) reserved for internal cluster services during the [control plane bootstrapping](08-bootstrapping-kubernetes-controllers.md#configure-the-kubernetes-api-server) lab.
.MD
.MD Check the 'Subject Alternative' field.
.MD ```
# Quick verification of the cert
openssl x509 -noout -in kubernetes.pem -text | grep "Subject Alt" -A 1
.MD ```
.MD
.MD View the created certificates
.MD
.MD ```
ls -lh *.pem
.MD ```
.MD Results:
.MD 
.MD ```
.MD kubernetes-key.pem
.MD kubernetes.pem
.MD ```
.MD 
.MD ## The Service Account Key Pair
.MD 
.MD The Kubernetes Controller Manager leverages a key pair to generate and sign service account tokens as described in the [managing service accounts](https://kubernetes.io/docs/admin/service-accounts-admin/) documentation.
.MD 
.MD Generate the `service-account` certificate and private key:
.MD 
.MD ```
# The Service Account Key Pair

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
.MD ```
.MD
.MD View the created certificates
.MD
.MD ```
ls -lh *.pem
.MD ```
.MD
.MD Results:
.MD 
.MD ```
.MD service-account-key.pem
.MD service-account.pem
.MD ```
.MD 
.MD ## Distribute the Client and Server Certificates
.MD
.MD Copy the appropriate certificates and private keys to each worker instance:
.MD

# Distribute the Client and Server Certificates

.MD Log out of the container to copy the files from the host:
.MD
.MD ```
# We need to log out of this container then copy the certs to the
# kubernetes nodes
exit
.MD ```
# All the certs should be in the kthw-certs directory
.MD
.MD Check that all the certs are on the host:
.MD
.MD ```
ls kthw-certs
.MD ```
.MD
# They are, good!
# Now to copy them, workers first:
# NOTE that 'sudo' is required as these are privileged containers
# that were created with 'sudo mokctl'.
.MD Change to the `kthw-certs` directory:
.MD
.MD ```
cd kthw-certs
.MD ```
.MD
.MD Copy the appropriate certificates and private keys to each worker instance:
.MD
.MD ```
for instance in kthw-worker-1 kthw-worker-2 kthw-worker-3; do
  sudo podman cp ca.pem ${instance}:/root
  sudo podman cp ${instance}-key.pem ${instance}:/root
  sudo podman cp ${instance}.pem ${instance}:/root
done
.MD ```
.MD
.MD Copy the appropriate certificates and private keys to each controller instance:
.MD
.MD ```
# Copy to the masters
for instance in kthw-master-1 kthw-master-2 kthw-master-3; do
  sudo podman cp ca.pem ${instance}:/root
  sudo podman cp ca-key.pem ${instance}:/root
  sudo podman cp kubernetes-key.pem ${instance}:/root
  sudo podman cp kubernetes.pem ${instance}:/root
  sudo podman cp service-account-key.pem ${instance}:/root
  sudo podman cp service-account.pem ${instance}:/root
done
.MD ```
# All done :)

# ------------------------------------------------------------------
# Next: Generating Kubernetes Configuration Files for Authentication
# ------------------------------------------------------------------
.MD > The `kube-proxy`, `kube-controller-manager`, `kube-scheduler`, and `kubelet` client certificates will be used to generate client authentication configuration files in the next lab.
.MD 
.MD Next: [Generating Kubernetes Configuration Files for Authentication](05-kubernetes-configuration-files.md)
```
