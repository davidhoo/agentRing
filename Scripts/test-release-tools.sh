#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
WORK=$(mktemp -d)
# Test artifacts only, intentionally retained on failure for inspection.
swiftc Scripts/verify-release.swift -o "$WORK/verify-release"
swift Tests/ReleaseToolsFixtures.swift "$WORK"
VERIFY=("$WORK/verify-release" "$WORK/AgentRing.app")
"${VERIFY[@]}" 1.2.3 "$WORK/appcast.xml" "$WORK/release.dmg" https://example.com/release.dmg
expect_failure() {
    local name="$1"
    shift
    if "$@" > "$WORK/rejected.log" 2>&1; then
        echo "FAIL: $name was accepted"
        exit 1
    fi
    echo "PASS: rejected $name"
}
expect_failure 'wrong bundle version' "${VERIFY[@]}" 9.9.9
expect_failure 'tampered archive' "${VERIFY[@]}" 1.2.3 "$WORK/appcast.xml" "$WORK/tampered.dmg" https://example.com/release.dmg
expect_failure 'wrong signing key' "${VERIFY[@]}" 1.2.3 "$WORK/wrong-key.xml" "$WORK/release.dmg" https://example.com/release.dmg
expect_failure 'missing signature' "${VERIFY[@]}" 1.2.3 "$WORK/unsigned.xml" "$WORK/release.dmg" https://example.com/release.dmg
expect_failure 'wrong download URL' "${VERIFY[@]}" 1.2.3 "$WORK/appcast.xml" "$WORK/release.dmg" https://example.com/other.dmg
expect_failure 'missing private key' swift Scripts/sparkle-key.swift < /dev/null
swift Scripts/sparkle-key.swift generate "$WORK/key" > "$WORK/public"
swift Scripts/sparkle-key.swift < "$WORK/key" > "$WORK/derived-public"
cmp "$WORK/public" "$WORK/derived-public"
expect_failure 'overwriting an existing key' swift Scripts/sparkle-key.swift generate "$WORK/key"
echo 'All release tooling checks passed.'
