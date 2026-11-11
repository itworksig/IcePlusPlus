<div align="center">
    <img src="icon.png" width="160" height="160" alt="Ice++">
    <h1>Ice++</h1>
    <p>A menu bar manager for macOS. Hide icons, open them from the Ice Bar, and switch layouts from presets and automations.</p>
    <p>Apple silicon only. macOS 14 or later.</p>
</div>

<p align="center"><a href="README_zh.md">简体中文</a></p>

[![Release](https://github.com/itworksig/IcePlusPlus/actions/workflows/release.yml/badge.svg)](https://github.com/itworksig/IcePlusPlus/actions/workflows/release.yml)
[![Download](https://img.shields.io/badge/download-Apple%20silicon-brightgreen?style=flat-square)](https://github.com/itworksig/IcePlusPlus/releases/latest)
![Platform](https://img.shields.io/badge/platform-macOS%2014%2B%20arm64-blue?style=flat-square)
[![License](https://img.shields.io/badge/license-GPL--3.0-blue?style=flat-square)](LICENSE)

The name on screen is **Ice++**. The bundle identifier is still `com.jordanbaird.Ice`, and preferences use that identifier, so this build can replace an Ice that is already installed.

## What it does

Put apps in Hidden or Always Hidden. Bring them back from the Ice Bar, a hotkey, Shortcuts, AppleScript, or a URL. A saved layout can also follow the displays you plug in, the frontmost app, the time of day, or the network you join.

Hiding is written for macOS 27. The system no longer gives each menu bar icon its own window, so a hide applies to the whole app.

## Where this line comes from

| | |
| --- | --- |
| [Jordan Baird's Ice](https://github.com/jordanbaird/Ice) | The original project. Sections, the Ice Bar, menu bar appearance, spacing, and hotkeys start there. License: GPL-3.0. |
| [cavaldos/Ice](https://github.com/cavaldos/Ice) | The community fork that carried Ice onto macOS 27. This repository's `upstream` remote points there. The fork point is `38c8a95` (`fix: remove padding left menubar`). |
| [itworksig/IcePlusPlus](https://github.com/itworksig/IcePlusPlus) | This repository. |

After that fork point, cavaldos kept working on Ice Bar item discovery, on keeping a hover from being saved into the layout, and on a star prompt after an update. Those commits are not in this tree.

## Differences from the original project

Original Ice is Jordan Baird's project. The upstream fork is cavaldos/Ice.

| | Original Ice | cavaldos/Ice | Ice++ |
| --- | --- | --- | --- |
| Name | Ice | Ice | Ice++. Bundle id `com.jordanbaird.Ice` |
| Language | English | English | English and Simplified Chinese. Changing language relaunches the app |
| Updates | Sparkle appcast | Its own releases, and the Homebrew tap `cavaldos/tap` | The About page reads GitHub Releases of this repository. There is no Homebrew formula |
| Builds | Published by the original repository | Published by cavaldos/Ice | Apple silicon only. A push to `main` publishes the next version. A higher major or minor in the project is published as written |
| Hiding on macOS 27 | Arranged through the per-icon windows of its time | Fixes so icons that disappeared or got stuck can use the older layout path | Hides by app through the system assessment allow-list. `com.apple.*` and Ice stay on the menu bar |
| System icons | Follow menu bar appearance | Follow menu bar appearance | Separate switches for Wi-Fi, Battery, Clock, and Control Center. Bluetooth and volume have no separate switch |
| Ice Bar | A second bar for the hidden section | The same bar, with later click and discovery work | A glass shelf with its own corner radius and tint. Search finds icons, presets, and automations. Arrow keys select, Return runs the row. The bar uses the display under the pointer |
| Presets | | | Save the current layout and apply it in one step. Bind it to the connected displays and it applies when that set is attached |
| Automations | | | Frontmost app, battery, time of day, Wi-Fi, location, date, power source, or a script. Pick a running app, fill the current network or location, and set the hours with a time picker |
| Focus | | | Hides third-party icons. The clock and Control Center stay, so volume and brightness UI keep working |
| Notch | Handled by layout and the Ice Bar | Handled by layout and the Ice Bar | Off until you turn it on. It moves a third-party icon only when that icon's center sits under the notch, and it does not relaunch Control Center to refresh |
| Control from outside | Hotkeys | Hotkeys | Hotkeys, Shortcuts, Siri, App Intents, AppleScript, `iceplusplus://`, and a Raycast source tree |
| Groups and widgets | | | Ice-owned icons. See the limits below |
| Configuration | Local preferences | Local preferences | Local preferences, plus export, import, and restore of the latest backup |

Ice++ still has the three sections (Visible, Hidden, Always Hidden), drag-and-drop layout, menu bar appearance and spacing, launch at login, and rehide by a smart rule, a timer, or an app change. It still needs Accessibility and Screen Recording.

## Limits on macOS 27

The layout page states these as well.

- A hide applies to a whole app. Several icons from one app move together.
- Bluetooth and volume sit outside the four switches. They stay in the menu bar.
- A group is an icon that belongs to Ice. Choosing a member brings that app back for about eight seconds. macOS cannot merge another app's icon into that menu item. Spacers and widgets belong to Ice as well.
- There is no iCloud sync. Take a configuration to another Mac with an exported file.

## Install

Download a build from [Releases](https://github.com/itworksig/IcePlusPlus/releases/latest).

| File | Use |
| --- | --- |
| `Ice-arm64.dmg` | Install by hand. Open it and drag `Ice.app` into Applications. |
| `Ice.zip` | The same arm64 app. Check for Updates replaces the running copy with this archive. |
| `release.json` | Version, build number, and architecture of that build. |

The archive is not notarized. If Gatekeeper blocks the first open:

```bash
xattr -d com.apple.quarantine /Applications/Ice.app
```

Then turn on Accessibility and Screen Recording under System Settings → Privacy & Security. A later install signed the same way keeps those grants. A package from GitHub is signed ad hoc, so the first time you switch to it you may need to turn the grants on again.

Ice++ asks for location only when an automation uses your place or Wi-Fi name, or when you click Use Current Location or Use Current Network.

## Check for updates

Check for Updates on the About page reads the latest Release of this repository.

1. Read `CFBundleShortVersionString` from the running app.
2. Request `https://api.github.com/repos/itworksig/IcePlusPlus/releases/latest`. Unsigned clients share 60 requests an hour. On HTTP 403 or 429, follow `https://github.com/itworksig/IcePlusPlus/releases/latest` to its tag and download `Ice.zip`.
3. Compare the tag `vX.Y.Z` with the local version as numbers. A `v` prefix and a suffix such as `-beta` are ignored. `1.0` and `1.0.0` are the same version.
4. A higher remote version is an update. An equal or lower version means this copy is current. An empty release list means nothing has been published yet.
5. Install and Reopen downloads `Ice.zip`, or `Ice-arm64.dmg` when the zip is absent. It checks that the app inside is `com.jordanbaird.Ice`, newer, and arm64, then replaces the running copy and opens it.

With automatic checks on, Ice++ looks once at launch and about every 24 hours after that. Nothing pops up when you are already current. With automatic download on, a newer build is downloaded first, and Ice++ asks before it quits the menu bar to install.

`Info.plist` still contains Sparkle feed keys. The About page does not read that appcast.

## Control it without opening the menu

```text
iceplusplus://focus
iceplusplus://show-hidden
iceplusplus://hide-hidden
iceplusplus://ice-bar
iceplusplus://preset?name=Office
```

The AppleScript application name is `Ice++`. Command text matches the URL host. A preset is `preset:` plus its name.

```applescript
tell application "Ice++" to do command "focus"
tell application "Ice++" to do command "preset:Office"
```

Shortcuts and Siri use these App Intents: toggle focus, show the hidden section, hide the hidden section, show the Ice Bar, and apply a preset.

`raycast/ice-plusplus` is the source of a Raycast extension that calls those URLs. Cloning this repository does not install the extension into Raycast.

## Publishing a version

A push to `main` runs the [Release workflow](.github/workflows/release.yml). When the major or minor number in the Xcode project is higher than the latest GitHub Release, that project version is what gets published. Later pushes on the same major and minor take the higher of the project version and the latest Release, then add one to the last component. The project file currently says **28.0.0**. You do not create the `vX.Y.Z` tag by hand.

The job runs on the `xcode-27` Apple silicon image, which includes Xcode 27. It uploads `Ice.zip`, `Ice-arm64.dmg`, and `release.json`, then writes the new version back to the project. That commit message contains `[skip ci]`, so the bookkeeping push does not publish a second build.

Running **Release Apple silicon** from the Actions page publishes another build.

If a Mac hosted runner is never acquired and the job is cancelled before any step starts, the [retry workflow](.github/workflows/retry-release.yml) queues it again, up to three attempts. A failure after the build has started stays failed.

This repository is a fork. GitHub leaves Actions off until they are enabled on the [Actions](https://github.com/itworksig/IcePlusPlus/actions) page. A push made before that click does not run later on its own.

## Local development

Build with Xcode.app and the macOS 27 SDK. Debug installs go to `/Applications/Ice-Dev.app` and are signed with the **Ice Dev** certificate in the login keychain, so Accessibility and Screen Recording survive a rebuild. The commands are in [script/README.md](script/README.md).

## License

[GPL-3.0](LICENSE). Thanks to [Jordan Baird](https://github.com/jordanbaird) for the original Ice, and to [cavaldos/Ice](https://github.com/cavaldos/Ice) for carrying it onto macOS 27.
