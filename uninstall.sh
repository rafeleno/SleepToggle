#!/bin/zsh

set -euo pipefail

readonly APP_NAME="SleepToggle"
readonly INSTALL_DIR="/Applications"
readonly INSTALLED_APP="$INSTALL_DIR/$APP_NAME.app"

if [[ ! -e "$INSTALLED_APP" ]]; then
    print "SleepToggle is not installed in $INSTALL_DIR."
    exit 0
fi

if [[ -w "$INSTALL_DIR" ]]; then
    /bin/rm -rf "$INSTALLED_APP"
else
    print "Administrator access is required to remove $INSTALLED_APP."
    /usr/bin/sudo /bin/rm -rf "$INSTALLED_APP"
fi

print "Removed: $INSTALLED_APP"
