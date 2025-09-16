#!/bin/bash -e

echo " "
echo " "
echo "▶️ Raspberry Pi build initiated"

PI_GEN_DIR="$(realpath ./pi-gen)"
echo "🧷 Making sure $PI_GEN_DIR is a safe Git directory"
if ! sudo git config --system --get-all safe.directory | grep -qx "$PI_GEN_DIR"; then
  sudo git config --system --add safe.directory "$PI_GEN_DIR"
fi

echo "♻️ Updating pi-gen submodule"
git submodule update --init

echo "✏️ Propagating config file settings"
./config/update-config.sh

echo "📂 Distributing config files"
cp config/pi-gen-config pi-gen/config
cp ./config.yaml overlay/common/etc/beaconbox/config.yaml

echo "📂 Distributing common overlay files"
cp -r overlay/common pi-gen/common-overlay

echo "⏳ Running pi-gen build (This may take a long time with limited/no output during this phase. Be patient. 🙂)"
cd pi-gen
./build-docker.sh > /dev/null 2>&1
cd ..

echo "🫱 Grabbing completed image"
sudo mv pi-gen/deploy/*.img .
echo "⌛ Build complete. Image: $(pwd)/$(ls -t *.img | head -1)"

echo "🪵 Build logs: "
echo " - $PI_GEN_DIR/deploy/build.log"
echo " - $PI_GEN_DIR/deploy/build-docker.log"

echo "✅ Raspberry Pi build complete"
