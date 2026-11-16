#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
TEST_DIR=$(mktemp -d "${TMPDIR:-/tmp}/ice-concealer-tests.XXXXXX")
trap 'rm -rf "$TEST_DIR"' EXIT
swiftc -parse-as-library \
    Ice/MenuBar/MacOS27/MenuBarConcealer27.swift \
    script/tests/menu-bar-concealer.swift \
    -o "$TEST_DIR/tests"
"$TEST_DIR/tests"
