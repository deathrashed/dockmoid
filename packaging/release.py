#!/usr/bin/env python3
"""Build a release from packaging/manifest.json; no Git or workspace files."""
import json
from pathlib import Path
import sys
import zipfile

root = Path(__file__).resolve().parent.parent
manifest = json.loads((root / 'packaging/manifest.json').read_text())
files = {Path(name) for name in manifest['files']}
excluded_parts = {'.git', 'work', 'scratch', 'tmp', 'tests', 'node_modules', '__pycache__'}
for directory, suffixes in manifest['trees'].items():
    for candidate in (root / directory).rglob('*'):
        relative = candidate.relative_to(root)
        if (candidate.is_file() and candidate.suffix in suffixes
                and not any(p.startswith('.') or p in excluded_parts for p in relative.parts)):
            files.add(relative)
required = {'metadata.json', 'contents/ui/main.qml', 'contents/icons/dockmoid.png',
            'contents/assets/library/NOTICE.md', 'LICENSE'}
if not required.issubset({p.as_posix() for p in files}):
    sys.exit('Manifest is missing required runtime assets or notices')
for relative in files:
    candidate = root / relative
    if not candidate.is_file() or candidate.is_symlink() or root not in candidate.resolve().parents:
        sys.exit(f'Unsafe or missing release file: {relative}')
output = Path(sys.argv[1] if len(sys.argv) > 1 else 'dockmoid.plasmoid').resolve()
if output == root or root in output.parents:
    # Generated releases belong outside the source tree to avoid accidental nesting.
    sys.exit('Choose an output path outside the source tree')
output.parent.mkdir(parents=True, exist_ok=True)
with zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED) as archive:
    for relative in sorted(files):
        archive.write(root / relative, relative.as_posix())
print(f'{output}: {len(files)} manifest files')
