#!/usr/bin/env bash
# Brings back every app removed by debloat.sh and hands the home screen and
# assistant button back to the stock software.
#
# Usage: ./scripts/restore.sh <box-ip>
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 <box-ip>" >&2
  exit 1
fi
export ANDROID_SERIAL="$1:5555"
cd "$(dirname "$0")"

adb connect "$ANDROID_SERIAL" >/dev/null

while read -r package _; do
  case "$package" in ''|\#*) continue ;; esac
  result=$(adb shell cmd package install-existing "$package" 2>&1 | tr -d '\r')
  printf '%-50s %s\n' "$package" "$result"
done < packages.txt

adb shell cmd package set-home-activity no.get.tv.androidtv.launcher/se.telia.androidtv.launcher.MainActivity || true
adb shell cmd role add-role-holder android.app.role.ASSISTANT com.google.android.katniss || true

# Turn off Volt Launcher's remote-button service, keeping any other accessibility services
enabled=$(adb shell settings get secure enabled_accessibility_services | tr -d '\r')
remaining=$(echo "$enabled" | tr ':' '\n' | grep -v '^com.voltlauncher.tv/' | paste -sd ':' - || true)
if [[ -z "$remaining" || "$remaining" == "null" ]]; then
  adb shell settings delete secure enabled_accessibility_services
else
  adb shell settings put secure enabled_accessibility_services "$remaining"
fi

echo
echo "Done. To remove Volt Launcher as well: adb uninstall com.voltlauncher.tv"
