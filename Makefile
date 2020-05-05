.PHONY: all install uninstall purge clean test unittest

all: mokctl.deploy tags

mokctl-docker: all
	cp mokctl.deploy package/
	docker build -t local/mokctl package

docker-hub-upload: mokctl-docker
	docker tag local/mokctl docker.io/mclarkson/mokctl
	docker push docker.io/mclarkson/mokctl

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
