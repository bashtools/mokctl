# Install mokctl on Linux

```bash
# ---------------------------------------------------------
# Kubernetes the Hard Way - using `mokctl` from My Own Kind
# ---------------------------------------------------------
# 03-compute-resources
# Create three masters and three workers and 1 more container for haproxy

alias mokctl="sudo mokctl"
mokctl build image --get-prebuilt-image
mokctl create cluster --skipmastersetup --skiplbsetup --with-lb kthw 3 3
# List the containers
mokctl get cluster kthw
# Accessing the containers:
mokctl exec kthw-master-1
# we're in!
exit
# Invoking the chooser
mokctl exec
5
# we're in!
exit
# ------------------------------------
# Next: Certificate Authority
# ------------------------------------

```
