VERSION = 0.8.4-alpha

.PHONY: all
all: mokctl.deploy tags

.PHONY: docker-builds
docker-builds: docker-mokctl docker-mokbox docker-baseimage

.PHONY: docker-uploads
docker-uploads: docker-builds docker-upload-mokctl docker-upload-mokbox docker-upload-baseimage

.PHONY: mokctl-docker-mokctl
docker-mokctl: all
	docker build -f package/Dockerfile.mokctl -t local/mokctl package
	docker tag local/mokctl myownkind/mokctl

.PHONY: mokctl-docker-mokbox
docker-mokbox: all
	docker build -f package/Dockerfile.mokbox -t local/mokbox package
	docker tag local/mokbox docker.io/myownkind/mokbox
	docker tag docker.io/myownkind/mokbox:latest docker.io/myownkind/mokbox:${VERSION}

.PHONY: mokctl-docker-baseimage
docker-baseimage: all
	bash mokctl.deploy build image
	docker tag local/mok-centos-7-v1.18.3 myownkind/mok-centos-7-v1.18.3
	docker tag myownkind/mok-centos-7-v1.18.3 myownkind/mok-centos-7-v1.18.3:${VERSION}

.PHONY: docker-upload-mokctl
docker-upload-mokctl: docker-mokctl
	docker push myownkind/mokctl
	docker tag myownkind/mokctl myownkind/mokctl:${VERSION}
	docker push myownkind/mokctl:${VERSION}

.PHONY: docker-upload-mokbox
docker-upload-mokbox: docker-mokbox
	docker push myownkind/mokbox
	docker push myownkind/mokbox:${VERSION}

.PHONY: docker-upload-baseimage
docker-upload-baseimage: docker-baseimage
	# mok-centos-7-v1.18.3 - Build with 'mokctl build image' first!
	docker push myownkind/mok-centos-7-v1.18.3
	docker push myownkind/mok-centos-7-v1.18.3:${VERSION}

mokctl.deploy: src/*.sh src/lib/*.sh mok-centos-7
	bash src/embed-dockerfile.sh
	cd src && ( echo '#!/usr/bin/env bash'; cat \
		main.sh lib/parser.sh globals.sh error.sh util.sh getcluster.sh \
		exec.sh deletecluster.sh createcluster.sh versions.sh containerutils.sh \
		buildimage.deploy lib/JSONPath.sh; \
		printf 'if [ "$$0" = "$${BASH_SOURCE[0]}" ] || [ -z "$${BASH_SOURCE[0]}" ]; then\n  MA_main "$$@"\nfi\n' \
		) >../mokctl.deploy
	chmod +x mokctl.deploy
	cp mokctl.deploy package/

.PHONY: install
install: all
	install cmdline-player/cmdline-player /usr/local/bin/cmdline-player
	install mokctl.deploy /usr/local/bin/mokctl

.PHONY: uninstall
uninstall:
	rm -f /usr/local/bin/mokctl /usr/local/bin/cmdline-player

.PHONY: clean
clean:
	rm -f mokctl.deploy src/buildimage.deploy package/mokctl.deploy \
		tests/hardcopy tests/screenlog.0

.PHONY: test
test: clean mokctl.deploy
	./tests/usage-checks.sh
	./tests/e2e-tests.sh
	shellcheck src/*.sh mokctl.deploy
	shfmt -s -i 2 -d src/*.sh

.PHONY: e2etest
e2etest: clean mokctl.deploy
	./tests/e2e-tests.sh

.PHONY: buildtest
buildtest: clean mokctl.deploy
	./tests/build-tests.sh

tags: src/*.sh
	ctags --language-force=sh src/*.sh src/lib/*.sh tests/unit-tests.sh

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

	./cmdline-player/scr2md.sh $$PWD/cmdline-player/kthw-10.scr \
	  "KTHW 10 Configuring kubetcl for Remote Access" \
		$$PWD/docs/kubernetes-the-hard-way/10-configuring-kubectl.md

	./cmdline-player/scr2md.sh $$PWD/cmdline-player/kthw-11.scr \
	  "KTHW 11 Provisioning Pod Network Routes" \
		$$PWD/docs/kubernetes-the-hard-way/11-pod-network-routes.md

	./cmdline-player/scr2md.sh $$PWD/cmdline-player/kthw-12.scr \
	  "KTHW 12 Deploying the DNS Cluster Add-on" \
		$$PWD/docs/kubernetes-the-hard-way/12-dns-addon.md

	./cmdline-player/scr2md.sh $$PWD/cmdline-player/kthw-13.scr \
	  "KTHW 13 Smoke Test" \
		$$PWD/docs/kubernetes-the-hard-way/13-smoke-test.md

	./cmdline-player/scr2md.sh $$PWD/cmdline-player/kthw-14.scr \
	  "KTHW 14 Cleaning Up" \
		$$PWD/docs/kubernetes-the-hard-way/14-cleanup.md

# vim:noet:ts=2:sw=2
