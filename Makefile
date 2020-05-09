.PHONY: all install uninstall purge clean test unittest

all: mokctl.deploy tags

mokctl-docker: all
	cp mokctl.deploy package/
	docker build --force-rm -t local/mokctl package

docker-hub-upload: mokctl-docker
	docker tag local/mokctl docker.io/mclarkson/mokctl
	docker push docker.io/mclarkson/mokctl
	# Build with 'mokctl build image'
	docker tag local/mok-centos-7-v1.18.2 docker.io/mclarkson/mok-centos-7-v1.18.2
	docker push docker.io/mclarkson/mok-centos-7-v1.18.2

mokctl.deploy: mokctl mok-centos-7
	bash mokctl/embed-dockerfile.sh
	chmod +x mokctl.deploy

install: all
	install mokctl.deploy /usr/local/bin/mokctl

uninstall:
	rm -f /usr/local/bin/mokctl

purge: uninstall
	rm -rf ~/.mok

clean:
	rm -f mokctl.deploy

test: clean mokctl.deploy
	./tests/unit-tests.sh
	shellcheck mokctl/mokctl
	shfmt -s -i 2 -d mokctl/mokctl

buildtest: clean mokctl.deploy
	./tests/build-tests.sh

tags: mokctl
	ctags --language-force=sh mokctl/mokctl tests/unit-tests.sh

# vim:noet:ts=2:sw=2
