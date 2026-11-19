#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if ! xcrun --sdk iphoneos --show-sdk-version | awk -F. '{ exit !($1 >= 27) }'; then
  echo 'This project needs Xcode with the iOS 27 SDK or newer.' >&2
  exit 1
fi
python3 scripts/verify-project.py
xcodebuild -project Scrollshot.xcodeproj -scheme Scrollshot -configuration Debug \
  -destination 'generic/platform=iOS' -derivedDataPath .build/apple CODE_SIGNING_ALLOWED=NO build
if [[ -n "${IOS_SIMULATOR_ID:-}" ]]; then
  xcodebuild -project Scrollshot.xcodeproj -scheme Scrollshot -configuration Debug \
    -destination "platform=iOS Simulator,id=$IOS_SIMULATOR_ID" -derivedDataPath .build/apple \
    CODE_SIGNING_ALLOWED=NO test
else
  echo 'Device build completed. To run adapter/render tests, set IOS_SIMULATOR_ID to an available iOS 27 simulator UUID and rerun.'
fi
