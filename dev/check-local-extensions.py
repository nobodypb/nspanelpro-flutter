#!/usr/bin/env python3
"""Enforce the local extension boundary before integrating upstream changes."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
package = root / 'packages/doorbird_intercom'
errors = []
for path in (root / 'lib').rglob('*.dart'):
    if path.is_relative_to(root / 'lib/local'):
        continue
    source = path.read_text()
    if re.search(r'doorbird|intercom|ha_companion|companion_handoff|nspanel-ha-app', source, re.I):
        errors.append(f'{path.relative_to(root)}: feature-specific coupling outside lib/local')
    if re.search(r'''import\s+['"][^'"]*local/''', source) and path != root / 'lib/app.dart':
        errors.append(f'{path.relative_to(root)}: only the composition root may import local implementations')
for path in (root / 'android/app').rglob('*'):
    if path.suffix not in {'.kt', '.kts', '.xml', '.cpp'} or not path.is_file():
        continue
    if re.search(r'doorbird|intercom|media3|companion|handoff', path.read_text(), re.I):
        errors.append(f'{path.relative_to(root)}: media implementation belongs in the plugin')
for package in [root / 'packages/doorbird_intercom', root / 'packages/ha_companion_handoff']:
    for path in (package / 'lib').rglob('*.dart'):
        for target in re.findall(r"(?:import|export)\s+['\"]([^'\"]+)", path.read_text()):
            if target.startswith('package:nspanel_app/'):
                errors.append(f'{path.relative_to(root)}: plugin imports its host')
            elif not target.startswith(('dart:', 'package:')):
                if not (path.parent / target).resolve().is_relative_to(package):
                    errors.append(f'{path.relative_to(root)}: relative import escapes plugin')
    for path in (package / 'android/src').rglob('*.kt'):
        if 'MainActivity' in path.read_text() or 'nspanel_app' in path.read_text():
            errors.append(f'{path.relative_to(root)}: plugin depends on the host activity/package')
for old in ['lib/intercom', 'vendor/audio-processing', 'dev/build-intercom-apm.py']:
    path = root / old
    if path.is_file() or path.is_dir() and any(path.rglob('*')):
        errors.append(f'{old}: legacy feature location still populated')
if errors:
    raise SystemExit('\n'.join(errors))
print('Local extension boundary OK: host uses capabilities; media package has no host dependency.')
