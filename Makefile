.PHONY: all build clean clean-all

all: build

build:
	git submodule update --init --recursive
	ln -sf ../config/pi-gen-config pi-gen/config
	ln -sf ../overlay pi-gen/overlay
	cd pi-gen && sudo env CONFIG_FILE=config ./build-docker.sh

clean:
	sudo docker rm -v pigen_work 2>/dev/null || true
	sudo docker image rm -f pi-gen 2>/dev/null || true
	sudo rm -rf pi-gen/work pi-gen/deploy

clean-all: clean
	sudo rm -f pi-gen/*.img pi-gen/*.zip
