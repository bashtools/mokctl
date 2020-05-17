>  **Kubernetes the Hard Way using My Own Kind**
> 
> View a [screencast and transcript](/cmdline-player/kthw-6.md)

# Generating the Data Encryption Config and Key

Kubernetes stores a variety of data including cluster state, application configurations, and secrets. Kubernetes supports the ability to [encrypt](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data) cluster data at rest.

In this lab you will generate an encryption key and an [encryption config](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/#understanding-the-encryption-at-rest-configuration) suitable for encrypting Kubernetes Secrets.

First 'log in' to the podman container that we created earlier:

```
podman exec -ti kthw bash
```

## The Encryption Key

Generate an encryption key:

```
ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)
echo $ENCRYPTION_KEY
```

Change to the `/certs` directory, which is volume mounted to the host:

```
cd /certs
```

## The Encryption Config File

Create the `encryption-config.yaml` encryption config file:

```
cat > encryption-config.yaml <<EOF
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${ENCRYPTION_KEY}
      - identity: {}
EOF
```

Check that the encryption-config.yaml file was created:
```
ls -lh *.yaml
```

Log out of the container to copy the kubeconfigs to the masters from the host:
```
exit
```

Check that the file exists on the host:

```
ls kthw-certs/*.yaml
```

Take a quick look at the file:

```
cat kthw-certs/*.yaml
```
Change to the `kthw-certs` directory:

```
cd kthw-certs
```

Copy the `encryption-config.yaml` encryption config file to each controller instance:

```
for instance in kthw-master-1 kthw-master-2 kthw-master-3; do
  sudo podman cp encryption-config.yaml ${instance}:/root
done
```
Next: [Bootstrapping the etcd Cluster](07-bootstrapping-etcd.md)
