# Debloat Android Phone – Quickshell OSD

![Preview](pic.png)

## Overview

This project provides a Wayland-compatible on-screen display (OSD) implemented in QML for Quickshell. It enables efficient management of applications on an Android device connected via USB debugging (ADB). The interface allows selective removal of pre-installed Google and third-party applications (debloating), restoration of previously uninstalled packages, file transfer between the host system and the device, process monitoring, and system reboot controls.

The OSD appears as a semi-transparent panel anchored to the right edge of the screen. It queries the connected device for installed and uninstalled packages, presents them in categorized lists with toggle controls, and executes the corresponding ADB commands when changes are applied.

## Features

- **Google Apps Tab**  
  Displays Google-related packages (including Chrome). Critical system components are automatically protected and excluded from modification.

- **Third-Party Apps Tab**  
  Lists launchable third-party applications and additional uninstalled packages that meet filtering criteria.

- **Search Tab**  
  Performs real-time filtering of all packages on the device by package name or friendly display name.

- **Reboot Tab**  
  Provides one-click reboot into Recovery mode or Bootloader / Fastboot mode.

- **Shared Tab**  
  Manages a dedicated folder (`/sdcard/SharedPC`) on the device. Supports drag-and-drop upload from the host and individual file download to `~/Downloads`.

- **Monitor Tab**  
  Displays a live, auto-refreshing view of processes obtained via `adb shell top`.

- **Device Information Bar**  
  Continuously shows manufacturer, model, Android version, and serial number.

- **Screen Mirroring**  
  Optional integration with scrcpy for an embedded, borderless preview window of the phone screen.

- **Safety Mechanisms**  
  Maintains an extensive list of protected packages and pattern-based filters that prevent accidental modification of essential system components.

## Requirements

- A Linux distribution running a Wayland compositor compatible with Quickshell.
- Android device with USB debugging enabled and authorized for the host.
- `adb` (Android Debug Bridge) and `scrcpy` installed on the host system.

## Installation of ADB and Related Tools on Arch Linux

Install the required packages with the following command:

```bash
sudo pacman -S android-tools scrcpy
