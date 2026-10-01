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

render = json.loads((root / 'App/Resources/plantRenderDefinitions.json').read_text(encoding='utf-8'))
assert set(render['definitions']) == set(ids)
assert render['isPlaceholder'] is True
for definition in render['definitions'].values():
    for kind in ('skeleton', 'leaf', 'flower', 'inflorescence'):
        name = definition[kind]
        if name == 'none':
            assert kind in ('flower', 'inflorescence')
            continue
        folder = root / 'App/Resources/Assets.xcassets' / (name + '.imageset')
        assert (folder / 'part.png').is_file(), name
        assert json.loads((folder / 'Contents.json').read_text())['images'][0]['filename'] == 'part.png'
assert len(list((root / 'Art/CoreV0').rglob('*.svg'))) == 54
project = (root / 'project.yml').read_text(encoding='utf-8')
assert "MARKETING_VERSION: '1.0.0'" in project
assert 'CFBundleDisplayName: Hanazukan' in project
print('PASS: 307 render mappings, 54 Core v0 SVG modules, asset references, v1.0 and SideStore naming')

attributes = json.loads((root / 'App/Resources/habitatAttributes.json').read_text(encoding='utf-8'))
assert len(attributes) == 307 and {a['latin'] for a in attributes} == set(ids)
for a in attributes:
    assert len(a['habitatScores']) == 8
    assert all(0 <= v <= 1 for v in a['habitatScores'].values())
    assert len(a['recommendedZones']) == 2
print('PASS: 307 habitat records, eight zone scores, recommendation coverage')

# The IPA reports exactly which source revision was built; do not infer from artifact names.
import os
info = {"version": "1.0.0", "commit": os.environ.get("GITHUB_SHA", "local-unpublished"), "run": os.environ.get("GITHUB_RUN_NUMBER", "local")}
(root / "App/Resources/buildInfo.json").write_text(json.dumps(info, indent=2) + "\n", encoding="utf-8")
print("Build provenance:", info)

slots = json.loads((root / 'App/Resources/gardenSlots.json').read_text(encoding='utf-8'))
spot_ids = set()
for garden, items in slots.items():
    for item in items:
        assert item['id'].startswith(garden + '-') and item['id'] not in spot_ids
        assert 0 <= item['x'] <= 1 and 0 <= item['y'] <= 1
        assert item['size'] in ('S', 'M', 'L', 'XL') and item['types']
        spot_ids.add(item['id'])
scene = json.loads((root / 'App/Resources/gardenScene.json').read_text(encoding='utf-8'))
assert len(scene['zones']) == 7 and len(scene['anchors']) >= 6
assert all(z['id'] in slots for z in scene['zones'])
tuning = json.loads((root / 'App/Resources/tuning_parameters_v1.json').read_text(encoding='utf-8'))
assert tuning['review']['interval_days'] == [1,3,7,14,30,60,120]
variants = json.loads((root / 'App/Resources/appearanceVariants.json').read_text(encoding='utf-8'))
assert set(variants['variants']) == set(ids)
for values in variants['variants'].values():
    assert len({v['id'] for v in values}) == len(values)
    for v in values:
        assert v['sourceNote'] and v['minimumPhotoCount'] >= 0
print('PASS: v1 slots, scene anchors, tuning, 307 appearance extension points')
