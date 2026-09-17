#!/bin/bash
# Ad-hoc sign nested Sparkle components without copying the host's sandbox to them.
set -euo pipefail
APP="${1:?Usage: bash Scripts/sign-app.sh /path/to/AgentRing.app}"
test -d "$APP/Contents/MacOS"
FRAMEWORK="$APP/Contents/Frameworks/Sparkle.framework"
test -d "$FRAMEWORK/Versions/B/XPCServices/Installer.xpc"

# Preserve the entitlements Xcode already expanded, including the sandbox's scoped IPC names.
WORK=$(mktemp -d)
trap 'rm -f "$WORK/host.plist"; rmdir "$WORK"' EXIT
/usr/bin/codesign -d --entitlements :- "$APP" > "$WORK/host.plist" 2>/dev/null
/usr/bin/plutil -lint "$WORK/host.plist"
if /usr/libexec/PlistBuddy -c 'Print :com.apple.security.get-task-allow' "$WORK/host.plist" >/dev/null 2>&1; then
    /usr/libexec/PlistBuddy -c 'Delete :com.apple.security.get-task-allow' "$WORK/host.plist"
fi

# The app already has network.client; do not ship an unused Downloader service.
if [[ -d "$FRAMEWORK/Versions/B/XPCServices/Downloader.xpc" ]]; then
    /bin/rm -r "$FRAMEWORK/Versions/B/XPCServices/Downloader.xpc"
fi
for COMPONENT in \
    "$FRAMEWORK/Versions/B/XPCServices/Installer.xpc" \
    "$FRAMEWORK/Versions/B/Autoupdate" \
    "$FRAMEWORK/Versions/B/Updater.app" \
    "$FRAMEWORK"; do
    /usr/bin/codesign --force --sign - --timestamp=none "$COMPONENT"
done
/usr/bin/codesign --force --sign - --timestamp=none --entitlements "$WORK/host.plist" "$APP"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP"
