.PHONY: all
all: mokctl.deploy tags

.PHONY: docs
docs:
	./cmdline-player/scr2md.sh $$PWD/cmdline-player/install-mokctl-linux.scr \
		"Install mokctl on Linux"

	./cmdline-player/scr2md.sh $$PWD/cmdline-player/kthw-2.scr \
	  "KTHW 02 Client Tools" \
		$$PWD/docs/kubernetes-the-hard-way/02-client-tools.md

	./cmdline-player/scr2md.sh $$PWD/cmdline-player/kthw-3.scr \
	  "KTHW 03 Compute Resources" \
		$$PWD/docs/kubernetes-the-hard-way/03-compute-resources.md

	./cmdline-player/scr2md.sh $$PWD/cmdline-player/kthw-4.scr \
	  "KTHW 04 Provisioning a CA and Generating TLS Certificates" \
		$$PWD/docs/kubernetes-the-hard-way/04-certificate-authority.md

	./cmdline-player/scr2md.sh $$PWD/cmdline-player/kthw-5.scr \
	  "KTHW 05 Generating Kubernetes Configuration Files for Authentication" \
		$$PWD/docs/kubernetes-the-hard-way/05-kubernetes-configuration-files.md

	./cmdline-player/scr2md.sh $$PWD/cmdline-player/kthw-6.scr \
	  "KTHW 06 Generating the Data Encryption Config and Key" \
		$$PWD/docs/kubernetes-the-hard-way/06-data-encryption-keys.md

	./cmdline-player/scr2md.sh $$PWD/cmdline-player/kthw-7.scr \
	  "KTHW 07 Bootstrapping the etcd Cluster" \
		$$PWD/docs/kubernetes-the-hard-way/07-bootstrapping-etcd.md

	./cmdline-player/scr2md.sh $$PWD/cmdline-player/kthw-8.scr \
	  "KTHW 08 Bootstrapping Kubernetes Controllers" \
		$$PWD/docs/kubernetes-the-hard-way/08-bootstrapping-kubernetes-controllers.md

	./cmdline-player/scr2md.sh $$PWD/cmdline-player/kthw-9.scr \
	  "KTHW 09 Bootstrapping Kubernetes Workers" \
		$$PWD/docs/kubernetes-the-hard-way/09-bootstrapping-kubernetes-workers.md

mokctl-docker: all
	cp mokctl.deploy package/
	sudo podman build --force-rm -t local/mokctl package

.PHONY: docker-hub-upload
docker-hub-upload: mokctl-docker
	sudo podman tag local/mokctl docker.io/mclarkson/mokctl
	sudo podman push docker.io/mclarkson/mokctl
	# Build with 'mokctl build image'
	sudo podman tag localhost/local/mok-centos-7-v1.18.2 docker.io/mclarkson/mok-centos-7-v1.18.2
	sudo podman push docker.io/mclarkson/mok-centos-7-v1.18.2

mokctl.deploy: mokctl mok-centos-7
	bash mokctl/embed-dockerfile.sh
	chmod +x mokctl.deploy

.PHONY: install
install: all
	install mokctl.deploy /usr/local/bin/mokctl

.PHONY: uninstall
uninstall:
	rm -f /usr/local/bin/mokctl

.PHONY: purge
purge: uninstall
	rm -rf ~/.mok

.PHONY: clean
clean:
	rm -f mokctl.deploy

.PHONY: test
test: clean mokctl.deploy
	./tests/unit-tests.sh
	shellcheck mokctl/mokctl
	shfmt -s -i 2 -d mokctl/mokctl

buildtest: clean mokctl.deploy
	./tests/build-tests.sh

tags: mokctl
	ctags --language-force=sh mokctl/mokctl tests/unit-tests.sh

# vim:noet:ts=2:sw=2
