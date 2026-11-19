#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
simulator_id=$(cat .build/simulator-id.txt)
# XCTest can shut down its destination after the tests. Boot before previewing.
xcrun simctl boot "$simulator_id" 2>/dev/null || true
xcrun simctl bootstatus "$simulator_id" -b
xcrun simctl install "$simulator_id" .build/simulator/Build/Products/Debug-iphonesimulator/Scrollshot.app
xcrun simctl launch "$simulator_id" local.scrollshot.iphone
sleep 3
xcrun simctl io "$simulator_id" screenshot .build/home-simulator.png
