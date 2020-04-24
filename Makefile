.PHONY: all install clean test unittest

all: mokctl.deploy

mokctl.deploy: mokctl mok-centos-7
	bash mokctl/embed-dockerfile.sh
	chmod +x mokctl.deploy

install:
	install mokctl.deploy /usr/local/bin/mokctl

clean:
	rm -f mokctl.deploy

test: clean mokctl.deploy unittest
	./tests/test_mokctl.sh

unittest: mokctl.deploy
	./tests/unit-tests.sh

# vim:noet:ts=2:sw=2
