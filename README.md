# Debloat Android Phone – Quickshell OSD

![Preview](pic.png)

## Overview

Debloat Android Phone is a Wayland-compatible on-screen display (OSD) written in QML for [Quickshell](https://github.com/outfoxxed/quickshell). It provides a convenient graphical interface for managing applications on an Android device connected via USB debugging (ADB).

The panel appears as a semi-transparent window anchored to the right edge of the screen. It queries the connected device for installed packages, presents them in organised lists with toggle controls, and executes the corresponding ADB commands when changes are applied. Additional tools for file transfer, process monitoring, telemetry hardening, and system reboot are also included.

## Features

- **Google Apps Tab**  
  Lists Google-related packages (including Chrome). Critical system components are automatically protected.

- **Third-Party Apps Tab**  
  Shows user-installed and other non-system packages that can be safely managed.

- **Search Tab**  
  Real-time filtering of all packages by package name or friendly display name. Supports smart keywords such as `services`, `google apps`, and `third party`.

- **Reboot Tab**  
  One-click reboot into Recovery mode or Bootloader / Fastboot mode.

- **Shared Tab**  
  Manages the `/sdcard/Download` folder on the device. Supports drag-and-drop upload from the host and individual file download to `~/Downloads`. Optional ClamAV malware scanning of the downloads folder is available when `clamscan` is installed on the host.

- **Monitor Tab**  
  Live, auto-refreshing view of processes obtained via `adb shell top`.

- **Secure Phone Tab**  
  - Detects and allows disabling of common telemetry / analytics settings  
  - Battery optimisation controls for third-party apps  
  - “Nuke Phone” sequence that applies a comprehensive set of privacy and performance hardening commands

- **Live Package Descriptions (Gemini)**  
  Left-click any package to obtain a concise description and a safety assessment (“Safe to remove: Yes / No / Caution”) powered by Google Gemini. Requires a free API key (see below).

- **Device Information Bar**  
  Continuously displays manufacturer, model, Android version, serial number, battery level, storage usage, and update status.

- **Screen Mirroring**  
  Optional integration with `scrcpy` for an embedded preview of the phone screen.

- **Safety Mechanisms**  
  Extensive protected-package list and pattern-based filters prevent accidental modification of essential system components.

## Requirements

- Linux distribution running a Wayland compositor supported by Quickshell
- Android device with USB debugging enabled and authorised for the host
- `adb` (Android Debug Bridge) installed on the host
- `scrcpy` (optional, for screen mirroring)
- `clamscan` (optional, for malware scanning of the downloads folder)
- Free Google Gemini API key (optional, for package descriptions)

## Installation of ADB and Related Tools (Arch Linux)

```bash
sudo pacman -S android-tools scrcpy clamav
Install the required packages with the following command:

```bash
sudo pacman -S android-tools scrcpy

## Gemini API Key (Optional – Package Descriptions)

To enable live package descriptions and safety assessments:

1. Obtain a free API key from [Google AI Studio](https://aistudio.google.com/apikey).

2. Create one of the following files and paste the key into it (one line only):

   **Recommended location**
   ```bash
   mkdir -p ~/.config/debloat-phone
   echo "YOUR_API_KEY_HERE" > ~/.config/debloat-phone/gemini.key
   chmod 600 ~/.config/debloat-phone/gemini.key
