"""Check source interchange integrity before subdivision/runtime conversion."""
import json
import math
from pathlib import Path

path = Path(__file__).resolve().parents[1] / 'References/CandidateModel/scene.json'
data = json.loads(path.read_text())
objects = data['objects']
report = {'objects': len(objects), 'materials': len(data['materials']), 'weightedMeshes': [], 'morphTargetsExcludingBase': 0}

def finite(value):
    if isinstance(value, float):
        assert math.isfinite(value), 'Nonfinite exported value'
    elif isinstance(value, dict):
        for v in value.values(): finite(v)
    elif isinstance(value, list):
        for v in value: finite(v)

finite(data)
for i, obj in enumerate(objects):
    assert obj['id'] == i
    assert -1 <= obj['parent'] < i
    count = len(obj.get('points', []))
    faces = obj.get('faces', [])
    for face in faces:
        assert len(face) in (3, 4) and all(0 <= v < count for v in face)
    for tag in obj['tags']:
        if 'material' in tag:
            assert 0 <= tag['material'] < len(data['materials'])
            if tag['selection']:
                assert any(t['type'] == 5673 and t['name'] == tag['selection'] for t in obj['tags'])
        if 'uvw' in tag:
            assert len(tag['uvw']) == len(faces)
        if tag['type'] == 5673:
            assert all(0 <= p < len(faces) for p in tag['faces'])
        if 'joints' in tag:
            for joint in tag['joints']:
                assert 0 <= joint['object'] < len(objects)
                assert objects[joint['object']]['type'] == 1019362
                assert len(joint['weights']) == count
                assert all(0 <= w <= 1 for w in joint['weights'])
            totals = [sum(j['weights'][p] for j in tag['joints']) for p in range(count)]
            assert max(abs(v - 1) for v in totals) < 0.0001
            report['weightedMeshes'].append({'name': obj['name'], 'joints': len(tag['joints']), 'weightSumRange': [min(totals), max(totals)]})
        if 'morphs' in tag:
            base = tag['morphs'][0]['points']
            for morph in tag['morphs']:
                assert len(morph['points']) == count
            for morph in tag['morphs'][1:]:
                assert any(a != b for a, b in zip(base, morph['points']))
                report['morphTargetsExcludingBase'] += 1
print(json.dumps(report, indent=2))
