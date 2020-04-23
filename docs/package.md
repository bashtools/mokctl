# My Own Kind - Package

When the RPMs are installed with `yum`, the containernetwork-plugins rpm is automatically installed as a dependency for cri-o, which copies a whole set of CNI networking plugins into `/usr/libexec/cni`, so we don't need to build them after all. We don't need the network plugins to be in `/opt/cni/bin` either, and it is not the right place for them to be when packages are installed using RPM - it's against the [guidelines](https://refspecs.linuxfoundation.org/FHS_3.0/fhs-3.0.pdf). Since many people will be expecting them to be there we can create a symlink in /opt/cni/bin instead, just to help people out. A better option might be to put a README file in `/opt/cni/bin` that contains the location of the plugins, or simply don't do it and let people find out for themselves.

## Keeping the same IP addresses
