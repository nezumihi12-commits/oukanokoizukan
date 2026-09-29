"""Portable integrity checks; actual Swift behavior is tested by XCTest on macOS."""
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
plants = json.loads((root / 'App/Resources/genera.json').read_text(encoding='utf-8'))
answers = json.loads((root / 'App/Resources/japaneseAnswers.json').read_text(encoding='utf-8'))
manifest = json.loads((root / 'docs/source-manifest.json').read_text(encoding='utf-8'))
assert len(plants) == manifest['count'] == 307
ids = [g['latin'] for g in plants]
assert len(set(ids)) == len(ids)
assert set(answers) == set(ids)
assert ids[0] == 'Abelia' and ids[-1] == 'Zinnia'
for g in plants:
    assert set(g) == set(manifest['fields'])
    assert all(isinstance(v, str) for v in g.values())
    assert g['latin'] and g['family'] and g['jpName']
    assert answers[g['latin']]['answers']
    assert answers[g['latin']]['pattern'] in 'ABC'
for relative, digest in manifest.get('resources', {}).items():
    assert hashlib.sha256((root / relative).read_bytes()).hexdigest() == digest, relative
assert (root / '.github/workflows/ios.yml').is_file()
assert (root / 'project.yml').is_file()
print('PASS: 307 unique genera, six original fields, Japanese answer coverage, resource hashes, project files')
