> [!NOTE]
> This repo is a work in progress. What's in the `main` branch should work, but there may be some rough edges. If you find any issues, please open an issue or a pull request.


# 🛸 BeaconBox

A fast-booting, lightweight Raspberry Pi* image designed for airgapped utility, offline resilience, and stealth deployment. BeaconBox automatically configures itself as a Wi-Fi access point and hosts a local web interface for easy interaction. People who connect to the broadcasted Wi-Fi network are greeted with a captive portal offering access to offline resources, tools, and information (when supported).

> *Tested on Raspberry Pi 4 and 5. x86_64 support is planned.

BeaconBox is great for:

- Red teams/penetration testing: Deploy a Wi-Fi SSID that encourages people who connect to download items of your choosing.
- Protestors/activists: Share information and tools in a low-profile way without relying on cellular or internet access, to people in a specific physical place.
- Field operations: Provide a local hub for maps, documents, and tools in remote areas without internet.
- Emergency preparedness: Create a local hub for critical information and tools during outages or disasters.
- Offline communities: Share files, documents, and tools without relying on internet connectivity.

## 🚀 Quick Start

### 🔧 Requirements

- Linux system with Docker installed
- Internet access (to pull base image)
- Enough free disk space (~5–10 GB)

### 🛠️ Build the image

```bash
make clean build
````

This will:

* Reset all build artifacts and overlays
* Propagate config settings
* Run the Dockerized `pi-gen` build
* Output a `.img` file in the root directory

### 📁 Output

After a successful build, you'll see something like:

```
▶️ Raspberry Pi build initiated
🧷 Making sure /home/himuglamuh/BeaconBox/pi-gen is a safe Git directory
♻️ Updating pi-gen submodule
✏️ Propagating config file settings
▶️ Running beaconbox config update...
📂 Copying template config to ./config/pi-gen-config...
🤲 Extracting username and password from ./config/../config.yaml...
✏️ Setting username and password in ./config/../config.yaml...
✅ Config update complete
📂 Distributing config files
📂 Distributing common overlay files
⏳ Running pi-gen build (This may take a long time with limited/no output during this phase. Be patient)
🫱 Grabbing completed image
⌛ Build complete. Image:
-rw-r--r-- 1 root   root   2.5G <date/time> <date>-beaconbox-os.img
🪵 Build logs: 
 - /home/himuglamuh/BeaconBox/pi-gen/deploy/build.log
 - /home/himuglamuh/BeaconBox/pi-gen/deploy/build-docker.log
✅ Raspberry Pi build complete
```

Flash the `.img` file to your SD card using `dd`, BalenaEtcher, or your preferred tool.

## 🧱 Project Structure

This section only explains files that you might want to modify. There's plenty more that you can explore if you're interested, but it's not necessary for basic usage.

```
BeaconBox/
├── config.yaml
├── overlay
    └── common
        └── srv
            └── beaconbox
                ├── files
                │   └── forbidden_knowledge.txt
                └── index.html
```

- `config.yaml` – Main configuration file. Set your SSID, password, and other options here.
- `overlay/common/srv/beaconbox/index.html` – The main web interface served to users who connect to the Pi. Customize this file to change the content. By default, it contains a simple welcome message with instructions for users of different devices on how to access and download files.
- `overlay/common/srv/beaconbox/files/` – Place any files you want to share with users here. They will be accessible via the web interface. You can pre-populate this directory with files before building the image, or add files later by accessing the Pi's filesystem.

## 🐛 Troubleshooting

- If you get a Git "safe directory" error, don’t worry—it’s handled in the build script.
- If your build is failing silently, check the full logs in `pi-gen/deploy/build.log` and `pi-gen/deploy/build-docker.log`.
- Need to debug a broken image? Boot it with a monitor and keyboard attached, or drop in a debugging SSH key via overlay.

### ❓ Default Values 

- **Username:** `beaconbox`
- **Password:** `beaconbox`
- **Wi-Fi SSID:** `BeaconBox`
- **Wi-Fi Password:** `none - open network`
> **Important:** Change these defaults in `config.yaml` before building for production use.
- SSH is enabled by default.

## 🧪 Future Enhancements

- Add build targets for other Raspberry Pi models
- Support for x86_64 builds
- Automatically serve files on connected USB drives 

## 🧨 Known Issues

### ❗ Kernel panic on iOS hotspot interactions (`cfg80211: Failed to start P2P device`)

**Symptoms:**
- BeaconBox appears to work fine until an iOS user taps the `ℹ️` info icon next to the network and attempts to **"Forget This Network"**
- This triggers a **kernel panic** and hard crash on the Pi
- Serial logs show (or similar):
```
cfg80211: Failed to start P2P device
Internal error: Oops: 96000004 \[#1] SMP

```

**Cause:**  
This is a **known Raspberry Pi kernel bug** involving the **cfg80211 subsystem** and **Wi-Fi P2P (Peer-to-Peer)** operations. iOS devices may attempt to initiate a P2P query when interacting with hotspot settings, triggering an unrecoverable kernel fault.

**Mitigation (what BeaconBox does):**
- We **do not disable P2P**, because that doesn’t fully prevent the issue in all cases
  - The bugged firmware ignores instructions to disable P2P
- Instead, BeaconBox is configured to:
  - **Automatically detect kernel panic crashes**
  - **Reboot as quickly as possible** to restore service with minimal downtime

**Why this works:**
- The crash only happens in rare user flows (e.g., forgetting the network on iOS - most users will just connect back to whatever network they were on previously)
- Recovery is nearly instant due to **aggressive boot time optimization** (sub-5s cold boot)

**Status:**  
🩹 **Crash detection and auto-reboot is implemented**  
⚠️ A future kernel fix may render this workaround obsolete

