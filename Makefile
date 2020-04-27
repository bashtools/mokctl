.PHONY: all install clean test unittest

all: mokctl.deploy

mokctl.deploy: mokctl mok-centos-7
	bash mokctl/embed-dockerfile.sh
	chmod +x mokctl.deploy

install: all
	install mokctl.deploy /usr/local/bin/mokctl

uninstall:
	rm -f /usr/local/bin/mokctl

clean:
	rm -f mokctl.deploy

test: clean mokctl.deploy
	./tests/unit-tests.sh

buildtest: clean mokctl.deploy
	./tests/build-tests.sh

# vim:noet:ts=2:sw=2
