# macOS Call Status Webhook Trigger

A lightweight, reliable macOS bash script that detects active Zoom or Microsoft Teams calls and fires webhooks (e.g., to Home Assistant) to automate your smart home (like turning on "On Air" lights or pausing your music).

Unlike scripts that scrape window titles or rely on unreliable hardware logs, this script monitors macOS **Power Assertions** via `pmset`. It detects exactly when Zoom or Teams requests the OS to stay awake for a meeting, making it extremely lightweight and highly accurate—even with USB webcams, Bluetooth headsets, and external audio docks.

This has only been tested on macOS Tahoe

## Features
* **Universal Detection:** Detects both Zoom and Microsoft Teams (including the newer "ms-teams" architecture).
* **Hardware Agnostic:** Works with built-in mics, AirPods, USB webcams, and Thunderbolt docks.
* **Minimal Footprint:** Polls a tiny system state every 5 seconds. Zero heavy log parsing or CPU spikes.
* **Secure by Design:** Keeps your private webhook URLs isolated in a hidden, untracked file to prevent accidental sharing.

## Prerequisites
* A macOS machine.
* Webhook URLs capable of receiving `POST` requests (like Home Assistant / Nabu Casa).

---

## Installation & Setup

### 1. Download the Script
Save `zoom-webhook.sh` to a permanent location on your Mac where it won't be moved or deleted. A good standard practice is to create a `bin` or `Scripts` folder in your home directory:
```bash
mkdir -p ~/bin
# Move the downloaded script into ~/bin
```

Make the script executable:
```bash
chmod +x ~/bin/zoom-webhook.sh
```

### 2. Configure Webhooks Securely
To prevent your private smart home URLs from being accidentally uploaded to GitHub or shared with others, this script reads them from a hidden file called `.webhooks`. 

Navigate to the directory where you saved the script and create the hidden file:
```bash
cd ~/bin
nano .webhooks
```

Add your webhook URLs inside the file using the `export` command:
```bash
export CALL_START="https://your-webhook-url-for-start"
export CALL_STOP="https://your-webhook-url-for-stop"
```
Save and exit (`Ctrl+O`, `Enter`, `Ctrl+X`).

**Lock the file:** Run this command to ensure only your specific macOS user account has permission to read this file:
```bash
chmod 600 .webhooks
```

---

## Running Automatically in the Background

To make this script run silently in the background every time you turn on your Mac, we use a macOS **LaunchAgent**. This is the native Apple way to manage background services using a `.plist` (Property List) configuration file.

An example file is provided in `examples/com.example.zoom-webhook.plist`.

### 1. Customize the `.plist` file
Open the example `.plist` file in any text editor. You **must** update the paths to match exactly where your script is located. macOS LaunchAgents do not understand the `~` shortcut for your home folder, so you must use absolute paths (e.g., `/Users/yourusername/...`).

Update these three strings in the file:
1. `<string>/Users/YOUR_USERNAME/path/to/zoom-webhook.sh</string>` *(The path to the script)*
2. `<string>/Users/YOUR_USERNAME/Library/Logs/zoom-webhook-launchagent.log</string>` *(Where standard output goes)*
3. `<string>/Users/YOUR_USERNAME/Library/Logs/zoom-webhook-launchagent.log</string>` *(Where error output goes)*

### 2. Install the LaunchAgent
Move your customized `.plist` file into your Mac's LaunchAgents folder:
```bash
cp examples/com.example.zoom-webhook.plist ~/Library/LaunchAgents/
```

### 3. Start the Background Service
Tell macOS to load the file and start running it immediately:
```bash
launchctl load ~/Library/LaunchAgents/com.example.zoom-webhook.plist
```
The script is now running in the background! It will automatically start up whenever you log into your Mac.

### Stopping the Service
If you ever need to stop the script or want to uninstall it, you must tell macOS to unload it:
```bash
launchctl unload ~/Library/LaunchAgents/com.example.zoom-webhook.plist
```

---

## Troubleshooting

If things aren't working as expected, you have two places to check for errors:

1. **The Script Log:** The script generates a `call-status.log` file in the same folder it lives in. Check this to see if it is successfully detecting your meetings and sending the webhooks.
   ```bash
   cat ~/bin/call-status.log
   ```
2. **The LaunchAgent Log:** If the script isn't starting at all, check the macOS LaunchAgent log to see if there is a path error or permission issue in your `.plist`.
   ```bash
   cat ~/Library/Logs/zoom-webhook-launchagent.log
   ```