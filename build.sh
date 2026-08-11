#!/bin/zsh

set -euo pipefail

readonly SCRIPT_DIR="${0:A:h}"
readonly APP_NAME="SleepToggle"
readonly APP_BUNDLE="$SCRIPT_DIR/$APP_NAME.app"
readonly BUILD_DIR="$SCRIPT_DIR/.build"
readonly STAGED_APP="$BUILD_DIR/$APP_NAME.app"
readonly MODULE_CACHE="$BUILD_DIR/ModuleCache"

if ! command -v xcrun >/dev/null 2>&1; then
    print -u2 "Error: Xcode Command Line Tools are required."
    print -u2 "Install them with: xcode-select --install"
    exit 1
fi

/usr/bin/plutil -lint "$SCRIPT_DIR/Info.plist" >/dev/null

/bin/rm -rf "$STAGED_APP"
/bin/mkdir -p \
    "$STAGED_APP/Contents/MacOS" \
    "$STAGED_APP/Contents/Resources" \
    "$MODULE_CACHE"

# Prefer the SDK matching the running macOS version. SDKROOT can be used to
# select a different SDK explicitly.
if [[ -n "${SDKROOT:-}" ]]; then
    readonly SDK_PATH="$SDKROOT"
else
    readonly MACOS_MAJOR="$(/usr/bin/sw_vers -productVersion | /usr/bin/cut -d. -f1)"
    if SDK_PATH="$(xcrun --sdk "macosx$MACOS_MAJOR" --show-sdk-path 2>/dev/null)"; then
        readonly SDK_PATH
    else
        readonly SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"
    fi
fi

export CLANG_MODULE_CACHE_PATH="$MODULE_CACHE"
export SWIFT_MODULECACHE_PATH="$MODULE_CACHE"

xcrun swiftc \
    -sdk "$SDK_PATH" \
    -O \
    "$SCRIPT_DIR/SleepToggle.swift" \
    -o "$STAGED_APP/Contents/MacOS/$APP_NAME" \
    -framework Cocoa \
    -framework Carbon

/bin/cp "$SCRIPT_DIR/Info.plist" "$STAGED_APP/Contents/Info.plist"
/usr/bin/codesign --force --sign - "$STAGED_APP"
/usr/bin/codesign --verify --deep --strict "$STAGED_APP"

/bin/rm -rf "$APP_BUNDLE"
/bin/mv "$STAGED_APP" "$APP_BUNDLE"

print "Built: $APP_BUNDLE"
