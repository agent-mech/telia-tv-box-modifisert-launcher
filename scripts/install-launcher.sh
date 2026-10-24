#!/usr/bin/env bash
# Installs Volt Launcher, makes it the home screen, routes the remote's assistant
# button to its quick menu, lets the passcode screen open when the box wakes, and
# turns on the remote-button remapping service.
#
# Usage: ./scripts/install-launcher.sh <box-ip> <path-to-volt-launcher.apk>
set -euo pipefail

if [ $# -ne 2 ]; then
  echo "Usage: $0 <box-ip> <path-to-volt-launcher.apk>" >&2
  exit 1
fi
export ANDROID_SERIAL="$1:5555"
PACKAGE=com.voltlauncher.tv

adb connect "$ANDROID_SERIAL" >/dev/null
adb install -r "$2"

adb shell cmd package set-home-activity "$PACKAGE/me.efesser.flauncher.MainActivity"
adb shell cmd role add-role-holder android.app.role.ASSISTANT "$PACKAGE"
adb shell appops set "$PACKAGE" SYSTEM_ALERT_WINDOW allow
# Desktop mode switches to an invisible keyboard; the TV settings page changes text size and screensaver delay
adb shell pm grant "$PACKAGE" android.permission.WRITE_SECURE_SETTINGS
adb shell appops set "$PACKAGE" WRITE_SETTINGS allow

# Remote button remapping (an accessibility service that only looks at key presses).
# Appended to any services that are already on instead of replacing them.
SERVICE="$PACKAGE/me.efesser.flauncher.RemoteKeyService"
enabled=$(adb shell settings get secure enabled_accessibility_services | tr -d '\r')
if [[ "$enabled" == "null" || -z "$enabled" ]]; then
  enabled="$SERVICE"
elif [[ ":$enabled:" != *":$SERVICE:"* ]]; then
  enabled="$enabled:$SERVICE"
fi
adb shell settings put secure enabled_accessibility_services "$enabled"
adb shell settings put secure accessibility_enabled 1

adb shell input keyevent KEYCODE_HOME
echo
echo "Home screen:      $(adb shell cmd package resolve-activity --brief -c android.intent.category.HOME -a android.intent.action.MAIN | tail -1)"
echo "Assistant button: $(adb shell settings get secure assistant)"
