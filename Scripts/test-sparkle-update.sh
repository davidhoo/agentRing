#!/bin/bash
# End-to-end test using a disposable sandboxed app + real Sparkle Installer XPC.
# Requires a logged-in macOS GUI session. No Agent Ring accounts or production app are touched.
# Usage: bash Scripts/test-sparkle-update.sh /path/to/SPM/artifacts/sparkle/Sparkle [valid|tampered-feed|tampered-archive]
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
SPARKLE="${1:?Provide the Sparkle SPM artifact directory}"
MODE="${2:-valid}"
[[ "$MODE" == valid || "$MODE" == tampered-feed || "$MODE" == tampered-archive ]]
FRAMEWORK="$SPARKLE/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
WORK=$(mktemp -d /tmp/agentring-update-smoke.XXXXXX)
IDENTIFIER="app.agentring.updatetest.$(uuidgen | tr '[:upper:]' '[:lower:]')"
echo "Test artifacts: $WORK"
echo "Test bundle: $IDENTIFIER"
mkdir "$WORK/feed"
python3 Tests/SparkleSmoke/server.py "$WORK" > "$WORK/server.log" 2>&1 &
SERVER_PID=$!
trap 'kill "$SERVER_PID" 2>/dev/null || true' EXIT
for _ in {1..20}; do
    [[ -s "$WORK/port" ]] && break
    kill -0 "$SERVER_PID"
    sleep 0.2
done
PORT=$(< "$WORK/port")
PUBLIC_KEY=$(swift Scripts/sparkle-key.swift generate "$WORK/test.key")
swift Tests/SparkleSmoke/prepare.swift "$WORK" "$IDENTIFIER" "$PUBLIC_KEY" "$PORT"
xcrun clang -fobjc-arc -Werror -Wno-incompatible-pointer-types -framework AppKit \
    -F "$(dirname "$FRAMEWORK")" -framework Sparkle -Wl,-rpath,@executable_path/../Frameworks \
    Tests/SparkleSmoke/main.m -o "$WORK/Smoke"
for FOLDER in installed payload; do
    APP="$WORK/$FOLDER/AgentRing.app"
    cp "$WORK/Smoke" "$APP/Contents/MacOS/Smoke"
    ditto "$FRAMEWORK" "$APP/Contents/Frameworks/Sparkle.framework"
    codesign --force --sign - --entitlements "$WORK/host.entitlements" "$APP"
    bash Scripts/sign-app.sh "$APP" >> "$WORK/signing.log" 2>&1
done
ln -s /Applications "$WORK/payload/Applications"
hdiutil create -quiet -volname 'AgentRing Update Test' -srcfolder "$WORK/payload" -format UDZO "$WORK/feed/update.dmg"
"$SPARKLE/bin/generate_appcast" --ed-key-file "$WORK/test.key" --maximum-deltas 0 \
    --download-url-prefix "http://127.0.0.1:$PORT/" -o "$WORK/feed/appcast.xml" "$WORK/feed" > "$WORK/appcast.log" 2>&1
swift Scripts/verify-release.swift "$WORK/payload/AgentRing.app" 2.0.0 "$WORK/feed/appcast.xml" "$WORK/feed/update.dmg" "http://127.0.0.1:$PORT/update.dmg"
"$SPARKLE/bin/sign_update" --ed-key-file "$WORK/test.key" --verify "$WORK/feed/appcast.xml"
if [[ "$MODE" != valid ]]; then
    swift Tests/SparkleSmoke/tamper.swift "$WORK/feed" "$MODE"
fi
RESULT="$HOME/Library/Containers/$IDENTIFIER/Data/Documents/sparkle-smoke-result.txt"
open -n "$WORK/installed/AgentRing.app"
for _ in {1..60}; do
    if [[ -f "$RESULT" ]] && /usr/bin/grep -Eq '^(PASS|REJECTED|FAIL)' "$RESULT"; then
        break
    fi
    sleep 1
done
if [[ -f "$RESULT" ]]; then
    cp "$RESULT" "$WORK/result.txt"
    more "$WORK/result.txt"
else
    echo "FAIL: no result from test app"
    exit 1
fi
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$WORK/installed/AgentRing.app/Contents/Info.plist")
if [[ "$MODE" == valid ]]; then
    /usr/bin/grep -q '^PASS: installed and relaunched 2.0.0' "$WORK/result.txt"
    [[ "$VERSION" == 2.0.0 ]]
    codesign --verify --deep --strict "$WORK/installed/AgentRing.app"
else
    /usr/bin/grep -q '^REJECTED:' "$WORK/result.txt"
    [[ "$VERSION" == 1.0.0 ]]
fi
echo "PASS: $MODE (installed version $VERSION)"
