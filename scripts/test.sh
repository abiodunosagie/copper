#!/bin/zsh
# Run the unit tests. Copper is quit first: the tests write to the system clipboard,
# and a running Copper would record those test copies in the real history.
set -euo pipefail

cd "$(dirname "$0")/.."
mkdir -p build
app_name="Copper"

osascript -e "quit app \"$app_name\"" 2>/dev/null || true
for _ in {1..50}; do
  pgrep -x "$app_name" > /dev/null || break
  sleep 0.2
done

xcodebuild test \
  -project Maccy.xcodeproj \
  -scheme Maccy \
  -derivedDataPath build/DerivedData \
  -destination 'platform=macOS' \
  -only-testing:MaccyTests \
  -allowProvisioningUpdates > build/test.log 2>&1 && result=0 || result=$?

grep -E "\\.swift:[0-9]+:[0-9]+: error|TEST (SUCCEEDED|FAILED)" build/test.log | sort -u || true
open -a "$app_name" 2>/dev/null || true
exit $result
