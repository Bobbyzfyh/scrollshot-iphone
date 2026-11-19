from pathlib import Path
import hashlib
import json
import zipfile

root = Path(__file__).resolve().parents[1]
allowed_dirs = {'Core', 'Scrollshot', 'Scrollshot.xcodeproj', 'scripts', 'tests', '.github'}
allowed_files = {'.gitignore', '.gitattributes', 'README.md', 'VALIDATION.md', 'REFERENCES.md', 'WINDOWS_INSTALL.md', 'APPLE-SAMPLE-LICENSE.txt'}
paths = sorted(path for path in root.rglob('*') if path.is_file() and (
    path.relative_to(root).parts[0] in allowed_dirs or path.relative_to(root).as_posix() in allowed_files
) and '__pycache__' not in path.parts and 'xcuserdata' not in path.parts)
manifest = {'version': '2.0.0-source', 'signed_app': False, 'files': {
    path.relative_to(root).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest() for path in paths
}}
output = root.parent / '长截图-iPhone原生版-源码.zip'
with zipfile.ZipFile(output, 'w', compression=zipfile.ZIP_DEFLATED) as archive:
    for path in paths:
        archive.write(path, path.relative_to(root).as_posix())
    archive.writestr('SOURCE-MANIFEST.json', json.dumps(manifest, indent=2, ensure_ascii=False))
with zipfile.ZipFile(output) as archive:
    for name, digest in manifest['files'].items():
        assert hashlib.sha256(archive.read(name)).hexdigest() == digest
    assert not any(name.startswith(('reference/', '.build/')) for name in archive.namelist())
print(f'Packaged {len(paths)} source files, verified hashes, {output.stat().st_size:,} bytes.')
print('Source only. No signed app, credentials, user media or reference downloads.')
