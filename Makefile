VERSION = 0.8.7-alpha

.PHONY: all
all: mokctl.deploy tags

.PHONY: docker-builds
docker-builds: docker-mokctl docker-mokbox docker-baseimage

.PHONY: docker-uploads
docker-uploads: docker-upload-mokctl docker-upload-mokbox docker-upload-baseimage

.PHONY: mokctl-docker-mokctl
docker-mokctl: all
	docker build -f package/Dockerfile.mokctl -t local/mokctl package
	docker tag local/mokctl myownkind/mokctl
	docker tag myownkind/mokctl myownkind/mokctl:${VERSION}

.PHONY: mokctl-docker-mokbox
docker-mokbox: all
	docker build -f package/Dockerfile.mokbox -t local/mokbox package
	docker tag local/mokbox docker.io/myownkind/mokbox
	docker tag docker.io/myownkind/mokbox:latest docker.io/myownkind/mokbox:${VERSION}

.PHONY: mokctl-docker-baseimage
docker-baseimage: all
	bash mokctl.deploy build image
	docker tag local/mok-centos-7-v1.18.4 myownkind/mok-centos-7-v1.18.4
	docker tag myownkind/mok-centos-7-v1.18.4 myownkind/mok-centos-7-v1.18.4:${VERSION}

.PHONY:
docker-upload-mokctl: docker-mokctl
	docker push myownkind/mokctl
	docker push myownkind/mokctl:${VERSION}

.PHONY: docker-upload-mokbox
docker-upload-mokbox:
	docker push myownkind/mokbox
	docker push myownkind/mokbox:${VERSION}

.PHONY: docker-upload-baseimage
docker-upload-baseimage:
	# mok-centos-7-v1.18.4 - Build with 'mokctl build image' first!
	docker push myownkind/mok-centos-7-v1.18.4
	docker push myownkind/mok-centos-7-v1.18.4:${VERSION}

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
	install mokctl.deploy /usr/local/bin/mokctl

.PHONY: uninstall
uninstall:
	rm -f /usr/local/bin/mokctl /usr/local/bin/cmdline-player

.PHONY: clean
clean:
	rm -f mokctl.deploy src/buildimage.deploy package/mokctl.deploy \
		tests/hardcopy tests/screenlog.0 tags

.PHONY: test
test: clean mokctl.deploy
	shellcheck mokctl.deploy
	shfmt -s -i 2 -d src/*.sh
	cd tests && ./usage-checks.sh && ./e2e-tests.sh

.PHONY: buildtest
buildtest: clean mokctl.deploy
	./tests/build-tests.sh

tags: src/*.sh
	ctags --language-force=sh src/*.sh src/lib/*.sh tests/unit-tests.sh

# vim:noet:ts=2:sw=2
