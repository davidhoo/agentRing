#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
SPARKLE="${1:?Provide the Sparkle SPM artifact directory}"
FRAMEWORK_DIR="$SPARKLE/Sparkle.xcframework/macos-arm64_x86_64"
WORK=$(mktemp -d)
swiftc -swift-version 5 -F "$FRAMEWORK_DIR" -framework Sparkle \
    -Xlinker -rpath -Xlinker "$FRAMEWORK_DIR" \
    AgentRing/Services/AppUpdateManager.swift Tests/UpdateManagerChecks.swift -o "$WORK/checks"
"$WORK/checks"
