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


Setting Up Your Samsung Phone for USB Debugging
Before the QuickShell OSD can communicate with your phone, you must enable Developer Options and USB Debugging:
1. Unlock Developer Mode:
25/08/2026, 18:11 Fixing Adb Shell Top Scrolling
https://gemini.google.com/app/5b12ce073939f174?pli=1 167/171
Open your phone Settings.
Scroll down and tap About phone -> Software information.
Locate the Build number row and tap it 7 times consecutively. Enter your lock screen PIN/pattern when prompted. You will see a
toast notification saying "Developer mode has been turned on".
2. Enable USB Debugging:
Go back to the main Settings menu.
Scroll down to the newly unlocked Developer options at the very bottom.
Scroll down inside Developer Options and toggle USB debugging to ON.
3. Authorize Your Computer:
Connect your Samsung phone to your Arch Linux machine via USB.
A prompt will appear on your phone screen asking: "Allow USB debugging?"
Check the box for "Always allow from this computer" and tap Allow.
4. Confirm Connection: Run adb devices again in your terminal. Your device serial number should now show up next to the word
device instead of unauthorized.
User prompt: no make everything so i can copy it
Response: # Samsung QuickShell QML OSD
![pic.png](pic.png)
A custom QuickShell QML On-Screen Display (OSD) designed specifically for managing, debloating, and interac
---
## Features
* **Device Control Dashboard:** Quick interface overlay for executing ADB commands and managing system pack
* **Samsung Package Management:** Safely target and toggle Samsung bloatware packages (`com.samsung.android
* **File & Screen Utilities:** Push wallpapers, files, or mirror your device screen seamlessly using integr
---
## Prerequisites: Installing ADB on Arch Linux
To interface with your Samsung phone, you need to install the Android Debug Bridge (`android-tools`) on Arc
Run the following command in your terminal using `pacman`:
```bash
sudo pacman -S android-tools
(Optional) If you also want to mirror and control your phone screen directly from your desktop, install scrcpy as well:
sudo pacman -S scrcpy
Verifying the Installation
Plug in your Android device via a data-capable USB cable and verify that the system detects it:
adb devices
Setting Up Your Samsung Phone for USB Debugging
Before the QuickShell OSD can communicate with your phone, you must enable Developer Options and USB Debugging:
1. Unlock Developer Mode:
Open your phone Settings.
Scroll down and tap About phone -> Software information.
Locate the Build number row and tap it 7 times consecutively. Enter your lock screen PIN/pattern when prompted. You will see a
toast notification saying "Developer mode has been turned on".
2. Enable USB Debugging:
25/08/2026, 18:11 Fixing Adb Shell Top Scrolling
https://gemini.google.com/app/5b12ce073939f174?pli=1 168/171
Go back to the main Settings menu.
Scroll down to the newly unlocked Developer options at the very bottom.
Scroll down inside Developer Options and toggle USB debugging to ON.
3. Authorize Your Computer:
Connect your Samsung phone to your Arch Linux machine via USB.
A prompt will appear on your phone screen asking: "Allow USB debugging?"
Check the box for "Always allow from this computer" and tap Allow.
4. Confirm Connection: Run adb devices again in your terminal. Your device serial number should now show up next to the word
device instead of unauthorized.
User prompt: Start over. write a complete step by step guide about this osd for github readme
Response: # Samsung QuickShell QML OSD
![pic.png](pic.png)
A comprehensive, custom QuickShell QML On-Screen Display (OSD) designed for Linux desktops to seamlessly ma
---
## Features
* **Multi-Tab Dashboard:** Clean, categorized tabs for Google apps, Third-party apps, live Search, Device R
* **Smart Package Debloating:** Safely manage and toggle Samsung and Google system packages with automatic
* **Interactive Touch Feedback:** Built-in scale animations and tactile styling for all buttons and interfa
* **Live Screen Mirroring:** Embed or toggle a borderless `scrcpy` window directly alongside your OSD.
* **Drag-and-Drop File Sharing:** Drop files straight onto the OSD to push them to your phone's shared stor
* **Live Process Monitoring:** Real-time system performance and process inspection (`adb shell top`) inside
---
## Prerequisites & Dependencies on Arch Linux
Before running the QuickShell OSD, make sure you have QuickShell, Android tools, and `scrcpy` installed on
### 1. Install Required Packages
Open your terminal and install Android Debug Bridge (`android-tools`) and `scrcpy`:
```bash
sudo pacman -S android-tools scrcpy
2. Verify ADB Detection
Connect your Samsung phone to your PC via a data-capable USB cable and verify that your system recognizes the device:
adb devices
Setting Up Your Samsung Phone for USB Debugging
To allow QuickShell to communicate with your device, you must enable Developer Options and authorize USB debugging:
1. Unlock Developer Mode:
Open your phone Settings.
Go to About phone -> Software information.
Locate Build number and tap it 7 times consecutively. Enter your lock screen PIN/pattern when prompted to unlock Developer
Options.
2. Enable USB Debugging:
Return to the main Settings menu.
Tap the newly unlocked Developer options at the bottom.
Scroll down and toggle USB debugging to ON.
3. Authorize the Computer:
25/08/2026, 18:11 Fixing Adb Shell Top Scrolling
https://gemini.google.com/app/5b12ce073939f174?pli=1 169/171
Leave your phone plugged into your Arch Linux PC.
When the "Allow USB debugging?" prompt appears on your screen, check "Always allow from this computer" and tap Allow.
4. Confirm Authorization: Run adb devices in your terminal again. Ensure your device ID appears next to device and not
unauthorized.
Installation & Setup
1. Clone or Place the Code: Place your QuickShell QML script file (e.g., debloat-phone.qml) into your local QuickShell configuration
directory.
2. Add the Cover Image: Ensure your preview screenshot is named pic.png and is located in the same directory as your QML script so
GitHub can render it correctly at the top of the repository.
3. Run QuickShell: Launch QuickShell pointing to your configuration directory or script:
quickshell
Usage Guide
Google & Third-Party Tabs: Browse installed or uninstalled packages. Toggle the switches to queue removals or restorations, then click
Apply at the bottom.
Search Tab: Type any app name or package keyword to filter and manage specific packages dynamically.
Reboot Tab: Quickly boot your phone into Recovery Mode or Bootloader/Fastboot mode for flashing or maintenance.
Shared Tab: Drag and drop files directly into the OSD area to upload them to /sdcard/SharedPC on your phone, or click Pull to PC to
download files back to your local ~/Downloads/ folder.
Monitor Tab: View live CPU and memory performance stats (top) streamed directly from your device.
Show/Close Phone Button: Instantly toggle a docked, borderless scrcpy window to interact with your phone screen right next to the
dashboard.
User prompt: put everything in markdown
Response: # Samsung QuickShell QML OSD
![pic.png](pic.png)
A comprehensive, custom QuickShell QML On-Screen Display (OSD) designed for Linux desktops to seamlessly ma
---
## Features
* **Multi-Tab Dashboard:** Clean, categorized tabs for Google apps, Third-party apps, live Search, Device R
* **Smart Package Debloating:** Safely manage and toggle Samsung and Google system packages with automatic
* **Interactive Touch Feedback:** Built-in scale animations and tactile styling for all buttons and interfa
* **Live Screen Mirroring:** Embed or toggle a borderless `scrcpy` window directly alongside your OSD.
* **Drag-and-Drop File Sharing:** Drop files straight onto the OSD to push them to your phone's shared stor
* **Live Process Monitoring:** Real-time system performance and process inspection (`adb shell top`) inside
---
## Prerequisites & Dependencies on Arch Linux
Before running the QuickShell OSD, make sure you have QuickShell, Android tools, and `scrcpy` installed on
### 1. Install Required Packages
Open your terminal and install Android Debug Bridge (`android-tools`) and `scrcpy`:
```bash
sudo pacman -S android-tools scrcpy
2. Verify ADB Detection
Connect your Samsung phone to your PC via a data-capable USB cable and verify that your system recognizes the device:
adb devices
25/08/2026, 18:11 Fixing Adb Shell Top Scrolling
https://gemini.google.com/app/5b12ce073939f174?pli=1 170/171
Setting Up Your Samsung Phone for USB Debugging
To allow QuickShell to communicate with your device, you must enable Developer Options and authorize USB debugging:
1. Unlock Developer Mode:
Open your phone Settings.
Go to About phone -> Software information.
Locate Build number and tap it 7 times consecutively. Enter your lock screen PIN/pattern when prompted to unlock Developer
Options.
2. Enable USB Debugging:
Return to the main Settings menu.
Tap the newly unlocked Developer options at the bottom.
Scroll down and toggle USB debugging to ON.
3. Authorize the Computer:
Leave your phone plugged into your Arch Linux PC.
When the "Allow USB debugging?" prompt appears on your screen, check "Always allow from this computer" and tap Allow.
4. Confirm Authorization: Run adb devices in your terminal again. Ensure your device ID appears next to device and not
unauthorized.
Installation & Setup
1. Clone or Place the Code: Place your QuickShell QML script file (e.g., debloat-phone.qml) into your local QuickShell configuration
directory.
2. Add the Cover Image: Ensure your preview screenshot is named pic.png and is located in the same directory as your QML script so
GitHub can render it correctly at the top of the repository.
3. Run QuickShell: Launch QuickShell pointing to your configuration directory or script:
quickshell
Usage Guide
Google & Third-Party Tabs: Browse installed or uninstalled packages. Toggle the switches to queue removals or restorations, then click
Apply at the bottom.
Search Tab: Type any app name or package keyword to filter and manage specific packages dynamically.
Reboot Tab: Quickly boot your phone into Recovery Mode or Bootloader/Fastboot mode for flashing or maintenance.
Shared Tab: Drag and drop files directly into the OSD area to upload them to /sdcard/SharedPC on your phone, or click Pull to PC to
download files back to your local ~/Downloads/ folder.
Monitor Tab: View live CPU and memory performance stats (top) streamed directly from your device.
Show/Close Phone Button: Instantly toggle a docked, borderless scrcpy window to interact with your phone screen right next to the
