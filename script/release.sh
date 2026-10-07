#!/bin/bash
# Version tags are no longer created by hand.
# Pushing to main bumps the patch version and publishes Ice.zip and Ice-arm64.dmg.
set -e
cd "$(dirname "$0")/.."

echo "Do not tag a release from this script."
echo "Push to main. GitHub Actions raises the patch number (27.0.1 -> 27.0.2),"
echo "builds the Apple silicon app, and uploads Ice.zip and Ice-arm64.dmg."
exit 1
