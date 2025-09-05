#!/bin/bash

set -e

echo "Removing old image if it exists"
docker rmi -f debos-rpi || true

echo "Building Raspberry Pi builder docker image"
docker build -f raspberrypi/rpibuilder.Dockerfile -t debos-rpi .
echo "Raspberry Pi builder image docker build complete"

echo "Building BeaconBox OS image"
docker run --rm -it --privileged \
  --tmpfs /run \
  --tmpfs /tmp:exec,dev \
  --device /dev/kvm \
  -v /dev:/dev \
  -v $(pwd)/:/workspace \
  debos-rpi \
  bash -c "mkdir -p /tmp/build && cp -r /workspace/* /tmp/build/ && cd /tmp/build/raspberrypi && debos --debug --disable-fakemachine beaconbox-rpi-minimal.yaml && cp /tmp/build/raspberrypi/beaconbox-pi.img /workspace/"
echo "BeaconBox OS image build complete"

echo "Cleaning up docker image"
docker rmi -f debos-rpi
echo "Cleanup complete"
