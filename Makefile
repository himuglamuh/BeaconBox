.PHONY: all build-pi clean-pi

all: build-pi

build-pi:
	sudo ./build-pi.sh

clean-pi:
	sudo docker rm -v pigen_work 2>/dev/null || true
	sudo docker image rm -f pi-gen 2>/dev/null || true
	sudo rm -rf pi-gen/work pi-gen/deploy pi-gen/config pi-gen/common-overlay
