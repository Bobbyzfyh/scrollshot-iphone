"""Portable structural checks; this is NOT a substitute for xcodebuild."""
from pathlib import Path
import plistlib
import re
import json
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[1]
app = root / 'Scrollshot'
info = plistlib.loads((app / 'Info.plist').read_bytes())
entitlements = plistlib.loads((app / 'Scrollshot.entitlements').read_bytes())
privacy = plistlib.loads((app / 'PrivacyInfo.xcprivacy').read_bytes())
assert info['UIBackgroundModes'] == ['screen-capture']
assert info['UISupportedInterfaceOrientations'] == ['UIInterfaceOrientationPortrait']
assert 'NSScreenCaptureUsageDescription' in info
assert 'NSPhotoLibraryAddUsageDescription' in info
assert not any(key in info for key in ['NSMicrophoneUsageDescription', 'NSCameraUsageDescription', 'NSPhotoLibraryUsageDescription', 'NSAppTransportSecurity'])
assert entitlements == {'com.apple.developer.screen-recording': True}
assert privacy['NSPrivacyTracking'] is False
assert privacy['NSPrivacyCollectedDataTypes'] == []
project = (root / 'Scrollshot.xcodeproj/project.pbxproj').read_text(encoding='utf-8')
definitions = re.findall(r'^\s*([A-F0-9]{24}) /\* .*? \*/ = \{', project, re.M)
assert len(definitions) == len(set(definitions)), 'Duplicate Xcode object IDs'
references = set(re.findall(r'\b[A-F0-9]{24}\b', project))
assert references == set(definitions), 'Unresolved Xcode object reference'
assert 'IPHONEOS_DEPLOYMENT_TARGET = "27.0"' in project
assert 'TARGETED_DEVICE_FAMILY = "1"' in project
assert 'Scrollshot/Scrollshot-Bridging-Header.h' in project
assert 'Scrollshot.entitlements' in project
for path in list(app.glob('*.swift')) + list((root / 'Core').glob('*.[ch]')):
    assert path.name in project, f'Missing from project: {path.name}'
scheme = ET.parse(root / 'Scrollshot.xcodeproj/xcshareddata/xcschemes/Scrollshot.xcscheme')
for reference in scheme.iter('BuildableReference'):
    assert reference.attrib['BlueprintIdentifier'] in definitions
icon = json.loads((app / 'Assets.xcassets/AppIcon.appiconset/Contents.json').read_text())
assert (app / 'Assets.xcassets/AppIcon.appiconset' / icon['images'][0]['filename']).is_file()
sources = '\n'.join(p.read_text(encoding='utf-8') for p in app.glob('*.swift'))
for forbidden in ['URLSession', 'WKWebView', 'AVAssetWriter', 'SCRecordingOutput(', 'SCClipBufferingOutput(', 'URLRequest', 'NSLog(', 'print(']:
    assert forbidden not in sources, f'Unexpected persistence/network/logging path: {forbidden}'
assert 'configuration.capturesAudio = false' in sources
assert 'configuration.showsMicrophoneControl = false' in sources
assert 'type: .microphone' not in sources and 'type: .audio' not in sources
assert 'PHPhotoLibrary.requestAuthorization(for: .addOnly)' in sources
assert 'UIApplication.willEnterForegroundNotification' in sources
assert 'ss_gate_accept' in sources
assert 'ss_archive_can_add' in sources
assert 'if pendingSince != nil' in sources
assert 'NSPhotoLibraryUsageDescription' not in info
print('PASS: project references, iPhone/iOS 27 settings, plist, resource, privacy and capture wiring checks')
print('NOT RUN: Swift SDK compilation, simulator tests, real-device capture, signing and installation')
