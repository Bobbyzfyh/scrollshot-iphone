#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build
cc -std=c11 -O2 -Wall -Wextra -Werror Core/SSMatcher.c tests/core_test.c -o .build/core-test-mac
.build/core-test-mac
xcrun simctl list devices available --json > .build/simulators.json
simulator_id=$(python3 - <<'PY'
import json
with open('.build/simulators.json') as handle:
    devices = json.load(handle)['devices']
candidates = [device for runtime, entries in devices.items() if 'iOS-27' in runtime
              for device in entries if device.get('isAvailable') and 'iPhone' in device['name']]
if not candidates:
    raise SystemExit('No iOS 27 iPhone simulator is installed; native adapter tests have not run.')
candidates.sort(key=lambda device: ('iPhone 17 Pro Max' not in device['name'], device['name']))
print(candidates[0]['udid'])
PY
)
xcodebuild -project Scrollshot.xcodeproj -scheme Scrollshot -configuration Debug \
  -destination "platform=iOS Simulator,id=$simulator_id" -derivedDataPath .build/simulator \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO test
xcrun simctl launch "$simulator_id" local.scrollshot.iphone
sleep 2
xcrun simctl io "$simulator_id" screenshot .build/home-simulator.png
