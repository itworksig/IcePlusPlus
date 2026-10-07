#!/bin/bash
# Step 2: fetch Ice.zip from the GitHub Release and publish appcast.xml.
# Without this, installed apps never see the update (SUFeedURL has no new entry).
# Usage: ./script/update-appcast.sh vX.Y.Z [--key <private-key.pem>] [--repo itworksig/IcePlusPlus]
# Env:   SPARKLE_PRIVATE_KEY=path/to/key.pem (matches SUPublicEDKey in Info.plist, never commit it).
#        Omit --key to use the private key stored in your Keychain instead.
#        DOWNLOAD_URL_PREFIX to override enclosure URLs (default: Ice releases for TAG)
# Needs: gh, generate_appcast (from Sparkle: https://sparkle-project.org/documentation/#publishing-updates)
set -e
cd "$(dirname "$0")/.."

TAG=""; KEY="${SPARKLE_PRIVATE_KEY:-}"; REPO="${ICE_REPO:-itworksig/IcePlusPlus}"
while [ $# -gt 0 ]; do
  case "$1" in
    --key) KEY="$2"; shift 2;;
    --repo|--releases-repo) REPO="$2"; shift 2;;
    -h|--help) sed -n '2,8p' "$0"; exit 0;;
    v*) TAG="$1"; shift;;
    *) echo "unknown arg: $1"; exit 1;;
  esac
done
if ! [[ "$TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "usage: $0 vX.Y.Z [--key <private-key.pem>]"
  exit 1
fi
command -v gh >/dev/null || { echo "missing gh — brew install gh"; exit 1; }
command -v generate_appcast >/dev/null || { echo "missing generate_appcast — download Sparkle tools (see header)"; exit 1; }
[ -z "$KEY" ] || [ -f "$KEY" ] || { echo "private key not found: '$KEY'"; exit 1; }
[ -n "$KEY" ] && KEY_ARG=(-f "$KEY") || KEY_ARG=()
PREFIX="${DOWNLOAD_URL_PREFIX:-https://github.com/${REPO}/releases/download/$TAG/}"

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
# Keep history when a previous appcast is already attached to a release.
gh release download -R "$REPO" -p 'appcast.xml' -D "$WORK" || true
gh release download "$TAG" -R "$REPO" -p 'Ice.zip' -D "$WORK"

generate_appcast "${KEY_ARG[@]}" --download-url-prefix "$PREFIX" "$WORK"
gh release upload "$TAG" -R "$REPO" "$WORK/appcast.xml" --clobber

echo "done — verify: https://github.com/${REPO}/releases/latest/download/appcast.xml contains $TAG"
echo "note: users only auto-update if 'Automatically check for updates' is ON in About"
