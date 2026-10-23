#!/usr/bin/env bash
# Removes Telia/GET operator software, Sagemcom telemetry and unneeded Google/Android extras.
#
# Apps are removed for the current user only ("pm uninstall --user 0"), not deleted from the
# system partition. A factory reset brings everything back, and so does scripts/restore.sh.
#
# Usage: ./scripts/debloat.sh <box-ip>
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 <box-ip>" >&2
  exit 1
fi
export ANDROID_SERIAL="$1:5555"
cd "$(dirname "$0")"

adb connect "$ANDROID_SERIAL" >/dev/null

# Refuse to remove the stock launcher unless another one is installed, or the box has no home screen
if ! adb shell pm path com.voltlauncher.tv >/dev/null 2>&1; then
  echo "Install the launcher first (scripts/install-launcher.sh), otherwise the box has no home screen." >&2
  exit 1
fi

failed=0
while read -r package _; do
  case "$package" in ''|\#*) continue ;; esac
  result=$(adb shell pm uninstall -k --user 0 "$package" 2>&1 | tr -d '\r')
  printf '%-50s %s\n' "$package" "$result"
  [[ "$result" == Success* || "$result" == *"not installed"* ]] || failed=1
done < packages.txt

exit $failed
