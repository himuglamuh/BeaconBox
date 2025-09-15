.PHONY: all build clean clean-all

all: build

build:
	sudo ./build-pi.sh

clean:
	sudo docker rm -v pigen_work 2>/dev/null || true
	sudo docker image rm -f pi-gen 2>/dev/null || true
	sudo rm -rf pi-gen/work pi-gen/deploy pi-gen/config pi-gen/common-overlay

clean-all: clean
	sudo rm -f pi-gen/*.img pi-gen/*.zip
