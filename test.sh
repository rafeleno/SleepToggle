#!/bin/zsh
set -euo pipefail
readonly SCRIPT_DIR="${0:A:h}"
readonly TEST_DIR="$SCRIPT_DIR/.build/Tests"
readonly MODULE_CACHE="$SCRIPT_DIR/.build/ModuleCache"
/bin/mkdir -p "$TEST_DIR" "$MODULE_CACHE"
# Compile the actual types from the single source, without the GUI entry point.
/usr/bin/awk '/^private struct HotKey:/ { exit } { print }' \
    "$SCRIPT_DIR/SleepToggle.swift" > "$TEST_DIR/main.swift"
/bin/cat "$SCRIPT_DIR/Tests/LidSessionTests.swift" >> "$TEST_DIR/main.swift"
xcrun swiftc -module-cache-path "$MODULE_CACHE" \
    -import-objc-header "$SCRIPT_DIR/IOKitMessages.h" \
    "$TEST_DIR/main.swift" -o "$TEST_DIR/check-lid-session" \
    -framework Cocoa -framework Carbon -framework IOKit
"$TEST_DIR/check-lid-session"
