# Samsung QuickShell QML OSD

![pic.png](pic.png)

A custom QuickShell QML On-Screen Display (OSD) designed specifically for managing, debloating, and interacting with **Samsung** Android devices directly from your Linux desktop via ADB (Android Debug Bridge) and `scrcpy`.

---

## Features
* **Device Control Dashboard:** Quick interface overlay for executing ADB commands and managing system packages.
* **Samsung Package Management:** Safely target and toggle Samsung bloatware packages (`com.samsung.android.*`).
* **File & Screen Utilities:** Push wallpapers, files, or mirror your device screen seamlessly using integrated tools.

---

## Prerequisites: Installing ADB on Arch Linux

To interface with your Samsung phone, you need to install the Android Debug Bridge (`android-tools`) on Arch Linux. 

Run the following command in your terminal using `pacman`:

```bash
sudo pacman -S android-tools
