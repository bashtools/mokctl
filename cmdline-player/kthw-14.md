# KTHW 14 Cleaning Up

![](../docs/images/kthw-14.gif)

View the [screencast file](../cmdline-player/kthw-14.scr)

```bash
# ---------------------------------------------------------
# Kubernetes the Hard Way - using `mokctl` from My Own Kind
# ---------------------------------------------------------
# 14-cleanup.md
# Cleaning Up

# Delete the cluster:
sudo mokctl delete cluster kthw
y
# Delete the podman container:
podman stop kthw
podman rm kthw
# Delete the certs directory:
rm -rf kthw-certs
# Delete the pod network routes:
ip ro | grep 10.200 | xargs -d'\n' -n1 sudo bash -c eval ip ro del

# All done :)

# ---------------------------------------
# You made it!! All finished - well done!
# ---------------------------------------
```
