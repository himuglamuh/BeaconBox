> [!NOTE]
> This repo is a work in progress, maintained by one guy in his limited spare time. What's in the `main` branch should work, but there may be some rough edges. If you find any issues, please open an issue or a pull request.


# 🛸 BeaconBox

A fast-booting, lightweight Raspberry Pi* image designed for airgapped utility, offline resilience, and stealth deployment. BeaconBox automatically configures itself as a Wi-Fi access point and hosts a local web interface for easy interaction. People who connect to the broadcasted Wi-Fi network are greeted with a captive portal (when supported) offering access to offline resources, tools, and information.

> *Tested on Raspberry Pi 4 and 5. x86_64 support is planned.

BeaconBox is great for:

- Red teams/penetration testing: Deploy a Wi-Fi SSID that encourages people who connect to download items of your choosing.
- Protestors/activists: Share information and tools in a low-profile way without relying on cellular or internet access, to people in a specific physical place.
- Field operations: Provide a local hub for maps, documents, and tools in remote areas without internet.
- Emergency preparedness: Create a local hub for critical information and tools during outages or disasters.
- Offline communities: Share files, documents, and tools without relying on internet connectivity.

## 🚀 Quick Start

### 🔧 Requirements

- Linux system with Docker, `make`, and `git` installed
  - Debian/Ubuntu/Mint: `sudo apt update && sudo apt install -y docker.io make git && sudo systemctl enable --now docker && sudo usermod -aG docker "$USER"`
  - Fedora/RHEL/CentOS: `sudo dnf install -y docker make git && sudo systemctl enable --now docker && sudo usermod -aG docker "$USER"`
  - Arch/Manjaro: `sudo pacman -Syu docker make git && sudo systemctl enable --now docker && sudo usermod -aG docker "$USER"`
- Internet access (to pull base image)
- Enough free disk space (~5–10 GB)

### 🛠️ Build the image

```bash
# Create an image for Raspberry Pi
make clean-pi build-pi
````

This will:

* Reset all build artifacts and overlays
* Propagate config settings
* Run the Dockerized image build
* Output a `.img` file and hash in the root directory

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
⌛ Build complete.
   Image: /home/himuglamuh/BeaconBox/<date>-beaconbox-os.img
   Size: 2.5G
   SHA256 Hash: b58b8595efbcd3b4419833932a95954249c3778a42f18e71bd7b191a18a9486b
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

- `config.yaml` – Main configuration file. Set your SSID, password, and other options here. You definitely want to change settings here before creating your own image and deploying it.
- `overlay/common/srv/beaconbox/index.html` – The main web interface served to users who connect to the Pi. Customize this file to change the content. By default, it contains a simple welcome message with instructions for users of different devices on how to access and download files. This is optional to change depending on your own use case.
- `overlay/common/srv/beaconbox/files/` – Place any files you want to share with users here. They will be accessible via the web interface. You can pre-populate this directory with files before building the image, or add files later by accessing the running BeaconBox filesystem, or by connecting a USB drive when BeaconBox is running. This folder comes with a sample `forbidden_knowledge.txt` file.

## 📁 USB Drive Auto-Sharing

BeaconBox supports automatic mounting and sharing of USB drives for quick access and file transfer.

- When a USB drive is inserted, it is:
  - Mounted to `/mnt/sdX`
  - Symlinked to `/srv/beaconbox/files/u-sdX` for easy access via the web interface
  - Made available for people connecting to the BeaconBox Wi-Fi network under `http://10.42.0.1/files/u-sdX`
- On boot and on each new USB connection, the system cleans up:
  - Any empty `u-*` folders in `/srv/beaconbox/files`
  - Any stale mountpoints in `/mnt`
- Drives are not unmounted on removal due to limitations in udev timing and permissions. This is intentional and handled gracefully:
  - Leftover directories are harmless (other than possible clutter in your `/files/` directory) and cleared on next USB insert or reboot
  - Lazy unmounting (`umount -l`) is used internally to prevent hangs

> [!TIP]
> In practice, most users won't hot-swap USB drives frequently. If needed, cleanup can also be triggered manually or on a scheduled task.

### ⚠️ USB Drive Behavior: Mounting Only When BeaconBox is Running

For security reasons, **BeaconBox only mounts USB drives that are plugged in *while the system is running.***

Drives that are already plugged in before boot **will not** be automatically mounted. You can, of course, mount and share them manually if you'd like.

Drives that were plugged in while BeaconBox was running will persist across reboots.

#### Why?

- This prevents BeaconBox from accidentally sharing **the same USB drive it's running from.**
- It also avoids mounting internal hard drives on x86\_64 systems.
- BeaconBox treats *hot-plugged USB drives* as intentional sharing behavior.

#### What this means for you:

- ✅ Plug in your USB drive **after BeaconBox has booted**.
- 🔄 If you reboot BeaconBox, **leave the USB drive plugged in**. Its folder will persist.
- ❌ Don't boot BeaconBox *from* the USB drive you want to share.

## 🐛 Troubleshooting

- If you get a Git "safe directory" error, don’t worry—it’s handled in the build script.
- If your build is failing silently, check the full logs in `pi-gen/deploy/build.log` and `pi-gen/deploy/build-docker.log`.
- Need to debug a broken image? Boot it with a monitor and keyboard attached, or drop in a debugging SSH key via overlay.

### ❓ Default Values 

- **Username:** `beaconbox`
- **Password:** `beaconbox`
> **Important:** Change these defaults in `config.yaml` before building for production use.
- **Wi-Fi SSID:** `BeaconBox`
- **Wi-Fi Password:** `none - open network`
- SSH is enabled by default.
- See `config.yaml` for more settings and their default values.

> [!TIP]
> After you setup your image to your liking, disable SSH to reduce attack surface, or disable password authentication in favor of key-based auth.

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
⚠️ A future fix may render this workaround obsolete

