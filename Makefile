VERSION = 0.8.11
K8SVERSION = 1.30.0

.PHONY: all
all: mok.deploy tags

.PHONY: docker-builds
docker-builds: docker-mok docker-mokbox docker-baseimage

.PHONY: docker-uploads
docker-uploads: docker-upload-mok docker-upload-mokbox docker-upload-baseimage

# .PHONY: mok-docker-mok
# docker-mok: all
# 	docker build --build-arg K8SVERSION=${K8SVERSION} -f package/Dockerfile.mok \
# 		-t local/mok package
# 	docker tag local/mok myownkind/mok
# 	docker tag myownkind/mok myownkind/mok:${VERSION}

# .PHONY: mok-docker-mokbox
# docker-mokbox: all
# 	docker build --build-arg K8SVERSION=${K8SVERSION} -f package/Dockerfile.mokbox \
# 		-t local/mokbox package
# 	docker tag local/mokbox docker.io/myownkind/mokbox
# 	docker tag docker.io/myownkind/mokbox:latest docker.io/myownkind/mokbox:${VERSION}

.PHONY: mok-docker-baseimage
docker-baseimage: all
	bash mok.deploy build image --tailf
	docker tag local/mok-image-v${K8SVERSION} myownkind/mok-image-v${K8SVERSION}
	docker tag myownkind/mok-image-v${K8SVERSION} myownkind/mok-image-v${K8SVERSION}:${VERSION}

.PHONY:
docker-upload-mok: docker-mok
	docker push myownkind/mok
	docker push myownkind/mok:${VERSION}

.PHONY: docker-upload-mokbox
docker-upload-mokbox:
	docker push myownkind/mokbox
	docker push myownkind/mokbox:${VERSION}

.PHONY: docker-upload-baseimage
docker-upload-baseimage:
	# mok-image-v${K8SVERSION} - Build with 'mok build image' first!
	docker push myownkind/mok-image-v${K8SVERSION}
	docker push myownkind/mok-image-v${K8SVERSION}:${VERSION}

mok.deploy: src/*.sh src/lib/*.sh mok-image
	bash src/embed-dockerfile.sh
	cd src && ( echo '#!/usr/bin/env bash'; cat \
		main.sh lib/parser.sh globals.sh error.sh util.sh getcluster.sh \
		exec.sh deletecluster.sh createcluster.sh versions.sh containerutils.sh \
		buildimage.deploy lib/JSONPath.sh; \
		printf 'if [ "$$0" = "$${BASH_SOURCE[0]}" ] || [ -z "$${BASH_SOURCE[0]}" ]; then\n  MA_main "$$@"\nfi\n' \
		) >../mok.deploy
	chmod +x mok.deploy
	# cp mok.deploy package/

.PHONY: install
install: all
	install mok.deploy /usr/local/bin/mok

.PHONY: uninstall
uninstall:
	rm -f /usr/local/bin/mok /usr/local/bin/cmdline-player

.PHONY: clean
clean:
	rm -f mok.deploy src/buildimage.deploy package/mok.deploy \
		tests/hardcopy tests/screenlog.0 tags

.PHONY: test
test: clean mok.deploy
	shellcheck mok.deploy
	shfmt -s -i 2 -d src/*.sh
	cd tests && ./usage-checks.sh && ./e2e-tests.sh

.PHONY: buildtest
buildtest: clean mok.deploy
	./tests/build-tests.sh

tags: src/*.sh
	ctags --language-force=sh src/*.sh src/lib/*.sh tests/unit-tests.sh

# vim:noet:ts=2:sw=2
