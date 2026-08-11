#!/bin/zsh

set -euo pipefail

readonly SCRIPT_DIR="${0:A:h}"
readonly APP_NAME="SleepToggle"
readonly SOURCE_APP="$SCRIPT_DIR/$APP_NAME.app"
readonly INSTALL_DIR="/Applications"
readonly INSTALLED_APP="$INSTALL_DIR/$APP_NAME.app"

"$SCRIPT_DIR/build.sh"

if [[ ! -d "$SOURCE_APP" ]]; then
    print -u2 "Error: build did not create $SOURCE_APP"
    exit 1
fi

if [[ -w "$INSTALL_DIR" ]]; then
    /bin/rm -rf "$INSTALLED_APP"
    /usr/bin/ditto "$SOURCE_APP" "$INSTALLED_APP"
else
    print "Administrator access is required to install into $INSTALL_DIR."
    /usr/bin/sudo /bin/rm -rf "$INSTALLED_APP"
    /usr/bin/sudo /usr/bin/ditto "$SOURCE_APP" "$INSTALLED_APP"
fi

print "Installed: $INSTALLED_APP"
print "Launch with: open '$INSTALLED_APP'"
