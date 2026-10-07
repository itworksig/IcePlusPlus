# Scripts

Local dev and release helpers. Run from the repository root.

## Local development

```bash
# Build Debug and launch the app
./script/run.sh

# Build Release DMG into release/ (optional version override for About)
./script/build.sh [vX.Y.Z]

# Same lint + build as CI — run before pushing (optional tag check)
./script/ci-local.sh [vX.Y.Z]
```

Install SwiftLint first if needed: `brew install swiftlint`.

## After installing a build

```bash
# Clear stale TCC entries so Accessibility / Screen Recording can be re-granted
./script/fix-permissions.sh [/path/to/Ice.app]
```

Ad-hoc signed builds are pinned to a `cdhash` that changes with every build, so the grant recorded for the previous binary stops matching — System Settings shows the toggle on while the app is denied. See [Permissions](../README.md#permissions).

## Every release

Check for Updates compares the installed version with the latest GitHub release tag. The tag has to be `vX.Y.Z` and newer than the running app. CI builds an Apple silicon `Ice.app` (in `Ice.zip`) and `Ice-arm64.dmg` and attaches both to that release.

```bash
# Commit your code, then create + push the tag (version comes from the tag name)
./script/release.sh vX.Y.Z
```

When the workflow is green, the release page should list `Ice.zip`, `Ice-arm64.dmg`, and `release.json`. Installed copies then offer that version from Settings → About → Check for Updates.

## Tag rules

* Format `vX.Y.Z` (e.g. `v27.0.2`) and **greater** than the version already installed. An equal or older tag is not offered.
* Never re-tag an old number. No need to touch the version in Xcode — CI injects `MARKETING_VERSION` from the tag name.
* `release.sh` refuses a dirty tree — commit + push first.

## No update showing? Check

1. Does `https://github.com/itworksig/IcePlusPlus/releases/latest` exist, and is its tag newer than the app's version?
2. Does that release include `Ice.zip` (used to install) or `Ice-arm64.dmg`?
3. Is **Automatically check for updates** on? The Check for Updates button works either way.
