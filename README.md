# Rotella — Another App for Smooth Scrolling

<img src="Resources/Rotella.png" alt="Rotella icon, a white mouse with a black scroll wheel" width="120">

Rotella is a macOS utility for smoother mouse-wheel scrolling and independent scroll directions for your mouse and trackpad. Once you install the background service, it starts at login and keeps working when you close or quit the app.

## What it does

- Reverse mouse and trackpad scrolling independently, relative to the macOS setting.
- Smooth discrete wheel steps and tune speed, acceleration, deceleration, and initial response.
- Install or uninstall the background service from the app window.

<img src="docs/rotella-settings.png" alt="Rotella settings showing service controls, scroll direction switches, and mouse-wheel sliders" width="560">

*Settings in the Italian interface. This screenshot shows an earlier build.*

## Installation guide

Requires macOS 13 or later on Intel or Apple Silicon. Install the Xcode Command Line Tools if needed:

```sh
xcode-select --install
```

Download or clone this repository, then run these commands from its root:

```sh
make check
open build
```

Drag **Rotella.app** from the build folder to **Applications** and open it there. The local build is signed ad hoc and does not need a Developer ID.

1. If Rotella detects the service from version 2, choose **Rimuovi servizio precedente** (Remove previous service).
2. Choose **Installa servizio** (Install service). If macOS requests approval, allow Rotella under **System Settings → General → Login Items & Extensions**.
3. Open **System Settings → Privacy & Security → Accessibility** and enable the **Rotella.app** you copied to Applications. If an entry from an earlier build is already present and Rotella still reports that it needs permission, remove that entry and add the current app again.

## How to use it

Open Rotella whenever you want to adjust settings. In **Direzione** (Direction), set the mouse and trackpad switches independently. Under **Rotella del mouse** (Mouse wheel), enable smooth scrolling and try the sliders in a long page as you make adjustments. A longer deceleration makes the wheel coast longer after the last step.

Devices that send continuous gesture events, such as Magic Mouse, follow the trackpad direction setting. The smoothing controls apply to wheels that send discrete steps. Scrolling with modifier keys uses the macOS behavior.

Choose **Disinstalla servizio** (Uninstall service) to stop it and remove it from automatic startup.

## Build a universal archive

```sh
make package ARCHS="arm64 x86_64"
```

The archive is written to `build/Rotella-macOS.zip`. For public distribution of the compiled app through GitHub Releases, sign with Developer ID and notarize it with Apple. [Apple notarization guide](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
