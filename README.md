<div align="center">
    <img src="icon.png" width="160" height="160" alt="Ice++">
    <h1>Ice++</h1>
    <p>Menu bar management for macOS. Section assignment, the Ice Bar, presets, and automations.</p>
    <p>Apple silicon. macOS 14 and later.</p>
</div>

<p align="center"><a href="README_zh.md">简体中文</a></p>

[![Release](https://github.com/itworksig/IcePlusPlus/actions/workflows/release.yml/badge.svg)](https://github.com/itworksig/IcePlusPlus/actions/workflows/release.yml)
[![Download](https://img.shields.io/badge/download-Apple%20silicon-brightgreen?style=flat-square)](https://github.com/itworksig/IcePlusPlus/releases/latest)
![Platform](https://img.shields.io/badge/platform-macOS%2014%2B%20arm64-blue?style=flat-square)
[![License](https://img.shields.io/badge/license-GPL--3.0-blue?style=flat-square)](LICENSE)

**Ice++** is the display name. The bundle identifier remains `com.jordanbaird.Ice`, and preferences are stored under that identifier. An existing Ice installation can therefore be replaced by this build.

## Overview

Ice++ assigns menu bar applications to Visible, Hidden, or Always Hidden. Hidden applications are restored through the Ice Bar, a hotkey, Shortcuts, AppleScript, or the `iceplusplus://` URL scheme. A stored layout may also be applied according to the connected displays, the frontmost application, the time of day, or the current network.

Concealment on macOS 27 is implemented against the system assessment allow-list. Individual status-item windows are no longer available, so concealment applies to an application as a whole. Processes in `com.apple.*`, and Ice itself, remain visible.

## Provenance

| Repository | Role |
| --- | --- |
| [Jordan Baird's Ice](https://github.com/jordanbaird/Ice) | Original project. Sections, the Ice Bar, menu bar appearance, item spacing, and hotkeys originate here. Licensed under GPL-3.0. |
| [cavaldos/Ice](https://github.com/cavaldos/Ice) | Community fork that maintained Ice on macOS 27. The `upstream` remote of this repository points there. The fork point is `38c8a95` (`fix: remove padding left menubar`). |
| [itworksig/IcePlusPlus](https://github.com/itworksig/IcePlusPlus) | This repository. |

Subsequent cavaldos commits, covering Ice Bar item discovery, exclusion of hover state from the saved layout, and a post-update star prompt, are not merged.

## Comparison

| | Original Ice | cavaldos/Ice | Ice++ |
| --- | --- | --- | --- |
| Product name | Ice | Ice | Ice++. Bundle identifier `com.jordanbaird.Ice` |
| Interface language | English | English | English and Simplified Chinese. A language change relaunches the application |
| Updates | Sparkle appcast | Project releases, plus the Homebrew tap `cavaldos/tap` | The About page queries GitHub Releases for this repository. No Homebrew formula is published |
| Distribution | Original repository | cavaldos/Ice | arm64 only. A push to `main` publishes the next version. A higher major or minor recorded in the project is published verbatim |
| Concealment on macOS 27 | Per-icon windows of that generation | Corrections for icons that disappeared or became unreachable, preserving the previous layout path | Per-application concealment through the assessment allow-list |
| System status items | Governed by menu bar appearance | Governed by menu bar appearance | Independent visibility for Wi-Fi, Battery, Clock, and Control Center. Bluetooth and volume have no independent control |
| Ice Bar | Secondary bar for the hidden section | The same bar, with later activation and discovery changes | Glass surface with an independent corner radius and tint. Search covers icons, presets, and automations. Arrow keys move the selection; Return activates it. Placement uses the display under the pointer |
| Presets | — | — | The current layout can be stored and applied directly. A preset may be bound to the connected display configuration and applied when that configuration is attached |
| Automations | — | — | Frontmost application, battery level, time of day, Wi-Fi, location, date, power source, or a script. The application is selected from running processes. Network name and location are taken from the current values. The schedule uses a time picker |
| Focus | — | — | Conceals third-party items. Clock and Control Center remain visible, so volume and brightness UI continue to function |
| Notch | Addressed through layout and the Ice Bar | Addressed through layout and the Ice Bar | Disabled by default. When enabled, a third-party icon is moved only if its center lies under the notch. Control Center is not relaunched to refresh |
| External control | Hotkeys | Hotkeys | Hotkeys, Shortcuts, Siri, App Intents, AppleScript, `iceplusplus://`, and a Raycast extension source tree |
| Groups and widgets | — | — | Status items owned by Ice. See [Platform constraints](#platform-constraints) |
| Configuration | Local preferences | Local preferences | Local preferences, with export, import, and restoration of the most recent backup |

The following behavior is retained: the three sections, drag-and-drop layout editing, menu bar appearance and spacing, launch at login, and automatic rehiding by a smart rule, a fixed interval, or a change of frontmost application. Accessibility and Screen Recording remain required.

## Platform constraints

These limits are also stated on the layout page. They follow from macOS 27.

- Concealment is scoped to the application. Multiple icons belonging to one application move together.
- Bluetooth and volume are outside the four system-item controls and remain in the menu bar.
- A group is a status item created by Ice. Activating a member returns that application to the menu bar for approximately eight seconds. The system does not permit another application's status item to be reparented into the group. Spacers and widgets are likewise owned by Ice.
- Configuration is local. Transfer between Macs is performed with an exported file. iCloud synchronization is not implemented.

## Installation

Release artifacts are published on [Releases](https://github.com/itworksig/IcePlusPlus/releases/latest).

| Artifact | Purpose |
| --- | --- |
| `Ice-arm64.dmg` | Manual installation. Open the image and move `Ice.app` to Applications. |
| `Ice.zip` | The same arm64 application. Check for Updates replaces the running copy from this archive. |
| `release.json` | Version, build number, and architecture of the artifact. |

The artifacts are not notarized. If Gatekeeper blocks the first launch, clear the quarantine attribute:

```bash
xattr -d com.apple.quarantine /Applications/Ice.app
```

Enable Accessibility and Screen Recording in System Settings → Privacy & Security. A subsequent installation that carries the same signature retains those grants. Packages downloaded from GitHub are ad-hoc signed, so the first substitution of such a package may require the grants to be enabled again.

Location authorization is requested only when an automation depends on location or the Wi-Fi name, or when Use Current Location or Use Current Network is invoked.

## Update mechanism

Check for Updates on the About page reads the latest Release of this repository.

1. The running application's `CFBundleShortVersionString` is read.
2. The client requests `https://api.github.com/repos/itworksig/IcePlusPlus/releases/latest`. Unauthenticated traffic shares a limit of 60 requests per hour. On HTTP 403 or 429, the client follows `https://github.com/itworksig/IcePlusPlus/releases/latest` to the resolved tag and downloads `Ice.zip`.
3. The tag `vX.Y.Z` is compared with the local version numerically. A leading `v` and a suffix such as `-beta` are excluded. `1.0` and `1.0.0` compare equal.
4. A greater remote version is an update. An equal or lower version indicates that the installed copy is current. An empty release list is reported as no published version.
5. Install and Reopen downloads `Ice.zip`, or `Ice-arm64.dmg` when the zip is absent. The payload must identify as `com.jordanbaird.Ice`, carry a higher version, and be arm64. The running copy is then replaced and relaunched.

When automatic checks are enabled, Ice++ queries once at launch and approximately every 24 hours thereafter. No dialog is presented when the installed version is current. When automatic download is enabled, a newer build is downloaded first, and installation proceeds only after confirmation.

`Info.plist` retains Sparkle feed keys. The About page does not consume that appcast.

## External control

```text
iceplusplus://focus
iceplusplus://show-hidden
iceplusplus://hide-hidden
iceplusplus://ice-bar
iceplusplus://preset?name=Office
```

The AppleScript application name is `Ice++`. Command text matches the URL host. A preset is addressed as `preset:` followed by its name.

```applescript
tell application "Ice++" to do command "focus"
tell application "Ice++" to do command "preset:Office"
```

Shortcuts and Siri expose these App Intents: toggle focus, show the hidden section, hide the hidden section, show the Ice Bar, and apply a preset.

`raycast/ice-plusplus` contains the source of a Raycast extension that invokes the URL scheme. Cloning the repository does not install the extension.

## Release process

A push to `main` starts the [Release workflow](.github/workflows/release.yml). If the major or minor component in the Xcode project is greater than that of the latest GitHub Release, the project version is published as recorded. Subsequent pushes on the same major and minor select the greater of the project version and the latest Release, then increment the final component. The project currently records **28.0.0**. The `vX.Y.Z` tag is created by the workflow.

The job runs on the `xcode-27` Apple silicon image, which provides Xcode 27. It uploads `Ice.zip`, `Ice-arm64.dmg`, and `release.json`, then writes the published version back to the project. The resulting commit message includes `[skip ci]`, so that write-back does not start another release.

**Release Apple silicon** can also be started manually from the Actions page.

If a Mac hosted runner is not acquired and the job is cancelled before any step executes, the [retry workflow](.github/workflows/retry-release.yml) queues the run again, up to three attempts. A failure after execution has begun is not retried by that workflow.

This repository is a fork. GitHub Actions remain disabled until they are enabled on the [Actions](https://github.com/itworksig/IcePlusPlus/actions) page. Pushes made before that point are not replayed.

## Development

Local builds require Xcode.app and the macOS 27 SDK. Debug products are installed at `/Applications/Ice-Dev.app` and signed with the **Ice Dev** certificate in the login keychain, so Accessibility and Screen Recording grants persist across rebuilds. Commands are documented in [script/README.md](script/README.md).

## License

Distributed under [GPL-3.0](LICENSE). Ice++ is based on [Ice](https://github.com/jordanbaird/Ice) by Jordan Baird, and on the macOS 27 maintenance carried by [cavaldos/Ice](https://github.com/cavaldos/Ice).
