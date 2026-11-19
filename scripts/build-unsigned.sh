#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if ! xcrun --sdk iphoneos --show-sdk-version | awk -F. '{ exit !($1 >= 27) }'; then
  echo 'This project needs Xcode with the iOS 27 SDK or newer.' >&2
  exit 1
fi
python3 scripts/verify-project.py
xcodebuild -project Scrollshot.xcodeproj -scheme Scrollshot -configuration Release \
  -destination 'generic/platform=iOS' -derivedDataPath .build/release CODE_SIGNING_ALLOWED=NO build
# A local ad-hoc signature embeds the requested entitlement for a later signer to
# inspect/preserve. It is NOT an Apple provisioning signature and cannot install.
app_path='.build/release/Build/Products/Release-iphoneos/Scrollshot.app'
codesign --force --sign - --entitlements Scrollshot/Scrollshot.entitlements "$app_path"
codesign --verify --strict "$app_path"
codesign -d --entitlements - "$app_path" > .build/embedded-entitlements.plist
python3 - <<'PY'
from pathlib import Path
import plistlib
import zipfile
with open('.build/embedded-entitlements.plist', 'rb') as handle:
    assert plistlib.load(handle).get('com.apple.developer.screen-recording') is True
app = Path('.build/release/Build/Products/Release-iphoneos/Scrollshot.app')
if not app.is_dir():
    raise SystemExit('Build did not produce an iPhone app.')
output = Path('.build/Scrollshot-unsigned.ipa')
with zipfile.ZipFile(output, 'w', compression=zipfile.ZIP_DEFLATED) as archive:
    for path in app.rglob('*'):
        if path.is_file():
            archive.write(path, 'Payload/Scrollshot.app/' + path.relative_to(app).as_posix())
print(f'Created {output}. This has only an AD-HOC signature and cannot be installed directly.')
print('A provisioning profile and Apple signature granting screen recording are still required.')
PY
