"""Inspect the delivered binary package without executing it or claiming it can install."""
from pathlib import Path
import hashlib
import plistlib
import struct
import sys
import zipfile

ipa = Path(sys.argv[1])
entitlements = Path(sys.argv[2])
with zipfile.ZipFile(ipa) as archive:
    names = archive.namelist()
    assert all(not name.startswith('/') and '..' not in name.split('/') for name in names)
    base = 'Payload/Scrollshot.app/'
    info = plistlib.loads(archive.read(base + 'Info.plist'))
    assert info['CFBundleIdentifier'] == 'local.scrollshot.iphone'
    assert info['CFBundleShortVersionString'] == '2.0.0'
    assert info['UIDeviceFamily'] == [1]
    assert info['MinimumOSVersion'] == '27.0'
    assert info['UIBackgroundModes'] == ['screen-capture']
    assert 'NSScreenCaptureUsageDescription' in info and 'NSPhotoLibraryAddUsageDescription' in info
    assert 'NSMicrophoneUsageDescription' not in info and 'NSCameraUsageDescription' not in info
    assert not any(name.endswith(('.html', '.js', '.mp4', '.mov')) for name in names)
    executable = archive.read(base + info['CFBundleExecutable'])
    header = struct.unpack_from('<8I', executable)
    assert header[0] == 0xFEEDFACF and header[1] == 0x0100000C and header[3] == 2, 'Expected native iPhone arm64 executable'
    offset = 32
    commands = []
    for _ in range(header[4]):
        command, size = struct.unpack_from('<II', executable, offset)
        assert size >= 8 and offset + size <= len(executable)
        commands.append(command)
        offset += size
    assert 0x1D in commands, 'Missing entitlement-preserving ad-hoc signature'
    assert b'ScreenCaptureKit.framework/ScreenCaptureKit' in executable
    assert b'com.apple.developer.screen-recording' in executable
    assert base + 'embedded.mobileprovision' not in names, 'Unexpected developer profile'
assert plistlib.loads(entitlements.read_bytes()) == {'com.apple.developer.screen-recording': True}
digest = hashlib.sha256(ipa.read_bytes()).hexdigest()
print(f'PASS: native arm64 iPhone/iOS 27 IPA, expected permissions and embedded screen-capture declaration; {ipa.stat().st_size:,} bytes')
print('No Apple provisioning profile: signing and real-device validation are still required.')
print('SHA256:', digest)
