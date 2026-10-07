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

Push to `main`. The Release Apple silicon workflow raises the patch number itself. It takes the higher of `MARKETING_VERSION` in the Xcode project and the latest GitHub release, then adds one to the last component (27.0.1 becomes 27.0.2). CI builds an Apple silicon `Ice.app`, uploads `Ice.zip` and `Ice-arm64.dmg`, and commits the new `MARKETING_VERSION` with `[skip ci]` so that bookkeeping push does not publish another build.

Do not create the version tag by hand, and do not run `./script/release.sh`. A tag push does not start this workflow.

When the workflow is green, the release page should list `Ice.zip`, `Ice-arm64.dmg`, and `release.json`. Installed copies then offer that version from Settings → About → Check for Updates. An equal or older release is not offered.

This repository is a fork. GitHub Actions stay off until they are enabled at https://github.com/itworksig/IcePlusPlus/actions. A push made before that click does not run later by itself.

## No update showing? Check

1. Does `https://github.com/itworksig/IcePlusPlus/releases/latest` exist, and is its tag newer than the app's version?
2. Does that release include `Ice.zip` (used to install) or `Ice-arm64.dmg`?
3. Is **Automatically check for updates** on? The Check for Updates button works either way.
