#!/usr/bin/env python3
"""Build an offline, reviewable report from the complete geometry audit."""
import csv
import json
import re
import shutil
from pathlib import Path

out = Path('Docs/Audits/2026-09-05-hand-geometry')
out.mkdir(parents=True, exist_ok=True)
catalog = set(re.findall(r'= "([^"]+)"', Path('Sources/BonziBuddy/Action.swift').read_text().split('    var duration:')[0]))
roots = {'normal': Path('Validation/GeometryAudit'), 'wearables': Path('Validation/GeometryAudit-wearables')}
all_data = {}
for mode, root in roots.items():
    summaries = json.loads((root / 'summary.json').read_text())
    assert {s['action'] for s in summaries} == catalog, 'Incomplete action catalog audit'
    all_data[mode] = {}
    for summary in summaries:
        name = summary['action'].lower().replace(' ', '-')
        data = json.loads((root / (name + '.json')).read_text())
        assert data['summary']['fps'] == 120 and len(data['frames']) == summary['frames']
        all_data[mode][summary['action']] = data
    (out / (mode + '-summary.json')).write_text(json.dumps(summaries, indent=2) + '\n')

engaged = [hand for mode in all_data.values() for data in mode.values()
           for frame in data['frames'] for hand in frame['hands'] if hand.get('intentWeight', 0) > .99999]
metrics = {'actions': len(catalog), 'configurations': len(roots), 'auditFPS': 120,
           'samplesPerConfiguration': {mode: sum(len(d['frames']) for d in datasets.values()) for mode, datasets in all_data.items()},
           'fullyEngagedHandSamples': len(engaged),
           'maximumHandAxisIntentErrorDegrees': max(h['intentErrorDegrees'] for h in engaged),
           'maximumPalmNormalIntentErrorDegrees': max(h['palmIntentErrorDegrees'] for h in engaged),
           'coordinateFrame': 'Default view: yaw 0, pitch 0.18 radians; +X screen right, +Y screen up, +Z toward viewer.',
           'limits': 'Sampled non-coplanar surface crossings, not penetration depth. No full containment, same-hand finger self-collision, floor, separate teeth mesh, or exhaustive interruption/hold/toggle timelines.'}
(out / 'coverage.json').write_text(json.dumps(metrics, indent=2) + '\n')
with (out / 'crossings.csv').open('w') as file:
    writer = csv.writer(file)
    writer.writerow(['configuration', 'action', 'pair', 'peak time seconds', 'triangle pairs', 'crossing frames', 'span x', 'span y', 'span z'])
    for mode, datasets in all_data.items():
        for action, data in datasets.items():
            for peak in data['summary']['peaks']:
                writer.writerow([mode, action, peak['pair'], peak['time'], peak['trianglePairs'], peak['sampledFramesWithCrossing'], *peak['span']])

cases = [
    ('Idle', 1.4, 'normal', 'left', 'Resting fingers overlap the torso and one another'),
    ('Read', 5.8, 'normal', 'quarter', 'Hand crosses the cover before the page turn'),
    ('Read', 9.833333, 'normal', 'left', 'Book crosses the forearm during stow'),
    ('Mail Read', 4.166667, 'normal', 'quarter', 'Letter panel crosses the hand during stow'),
    ('Write', .733333, 'normal', 'left', 'Pad crosses the forearm during retrieval'),
    ('Headphones', 1.6, 'normal', 'quarter', 'Cup shell crosses the fingers during placement'),
    ('Globe', 2.633333, 'normal', 'front', 'Supporting finger extends inside the globe'),
    ('Mail Empty', .8, 'normal', 'quarter', 'Hand passes through the mailbox door'),
    ('Butterfly', 4.966667, 'normal', 'quarter', 'Touching finger crosses a wing'),
    ('Banana', 2.3, 'normal', 'quarter', 'Peel crosses the gripping fingers'),
    ('Juggle', .6, 'normal', 'quarter', 'Catch contact: smaller priority than paper transfers'),
    ('Surprised', .233333, 'wearables', 'quarter', 'Raised hand crosses the earcup'),
    ('Clap', .266667, 'normal', 'left', 'Opposed palms; forearm/chest clearance needs refinement'),
]
photos = []
with (out / 'selected-hand-directions.csv').open('w') as file:
    writer = csv.writer(file)
    writer.writerow(['configuration', 'action', 'time', 'side', 'hand yaw degrees', 'hand elevation degrees', 'hand x', 'hand y', 'hand z', 'palm x', 'palm y', 'palm z', 'index x', 'index y', 'index z'])
    for action, time, mode, view, title in cases:
        source = roots[mode] / (f'{action.lower().replace(" ", "-")}-{time:.3f}-{view}.png')
        target = mode + '-' + source.name
        shutil.copyfile(source, out / target)
        photos.append({'action': action, 'time': time, 'mode': mode, 'src': target, 'title': title})
        frame = min(all_data[mode][action]['frames'], key=lambda f: abs(f['time'] - time))
        for hand in frame['hands']:
            writer.writerow([mode, action, frame['time'], hand['side'], hand['handYawDegrees'], hand['handElevationDegrees'], *hand['handDirection'], *hand['palmNormal'], *hand['indexDirection']])

viewer = {'metrics': metrics, 'photos': photos, 'modes': {}}
for mode, datasets in all_data.items():
    viewer['modes'][mode] = {}
    for action, data in datasets.items():
        selected = set(range(0, len(data['frames']), 12)) | {len(data['frames']) - 1}
        for peak in data['summary']['peaks']:
            selected.add(min(range(len(data['frames'])), key=lambda i: abs(data['frames'][i]['time'] - peak['time'])))
        rows = []
        for i in sorted(selected):
            frame = data['frames'][i]
            hands = [[round(v, 4) for key in ['wrist', 'handDirection', 'palmNormal', 'indexDirection'] for v in hand[key]] for hand in frame['hands']]
            crossings = [[c['pair'], c['trianglePairs'], round(max(c['span']), 4)] for c in frame['crossings']]
            rows.append([round(frame['time'], 4), hands, crossings])
        viewer['modes'][mode][action] = rows
payload = json.dumps(viewer, separators=(',', ':')).replace('<', '\\u003c')
html = '''<!doctype html><html lang="en"><meta charset="utf-8"><title>Bonzi hand and geometry audit</title>
<style>body{font:16px system-ui;max-width:1150px;margin:32px auto;padding:0 20px;color:#222;background:#fafafa}h1{font-size:28px}select,input{font:inherit;margin:8px}table{border-collapse:collapse;width:100%;background:white}th,td{padding:8px;border-bottom:1px solid #ddd;text-align:left}small,.note{color:#555}#diagrams{display:flex;gap:24px;flex-wrap:wrap}svg{background:white;border:1px solid #ddd}figure{margin:16px 0;max-width:540px}img{width:100%;height:auto}#photos{display:flex;flex-wrap:wrap;gap:20px}button{cursor:pointer;font:inherit}code{font-size:13px}</style>
<h1>Hand directions and geometry audit</h1><p id="coverage"></p>
<p class="note">Blue: hand axis · Orange: palm normal · Green: index direction. Axes use the default view (+X right, +Y up, +Z toward viewer, camera pitch 0.18 rad). A curled index finger need not point along the hand axis.</p>
<label>Animation <select id="action"></select></label><label>Accessories <select id="mode"><option value="normal">Normal</option><option value="wearables">Sunglasses + headphones</option></select></label>
<div><label>Time <input id="time" type="range" min="0" value="0" style="width:70%"></label><output id="seconds"></output></div>
<p class="note">The viewer selects 10 Hz samples plus peak-crossing frames. The underlying audit ran at 120 Hz. Triangle-pair counts and crossing spans are diagnostics, not penetration depth or automatic severity scores.</p>
<table><thead><tr><th>Hand</th><th>Yaw / elevation</th><th>Palm normal (X,Y,Z)</th><th>Index direction (X,Y,Z)</th></tr></thead><tbody id="hands"></tbody></table>
<div id="diagrams"></div><h2>Surface crossings at this time</h2><div id="crossings"></div><h2>Reviewed examples</h2><div id="photos"></div>
<p class="note" id="limits"></p><script type="application/json" id="data">PAYLOAD</script>
<script>
const data=JSON.parse(document.getElementById('data').textContent),$=id=>document.getElementById(id);
const names=Object.keys(data.modes.normal);for(const name of names){const option=document.createElement('option');option.value=name;option.textContent=name;$('action').append(option)}
$('coverage').textContent=`${data.metrics.actions} animations, two configurations, ${Object.values(data.metrics.samplesPerConfiguration).reduce((a,b)=>a+b,0).toLocaleString()} samples at 120 Hz.`;
$('limits').textContent=data.metrics.limits;
const fmt=v=>v.map(x=>x.toFixed(2)).join(', ');
function diagram(hand,label){let text=`<div><p>${label}</p>`;for(const [a,b,title] of [[0,1,'Front X/Y'],[0,2,'Top X/Z'],[2,1,'Side Z/Y']]){text+=`<svg width="150" height="160" viewBox="0 0 150 160"><text x="8" y="16" font-size="12">${title}</text><path d="M15 90H135M75 30V150" stroke="#ddd"/>`;for(const [offset,color] of [[3,'#1689dc'],[6,'#e58a22'],[9,'#25a649']]){const x=75+hand[offset+a]*55,y=90-hand[offset+b]*55,angle=Math.atan2(y-90,x-75);text+=`<path d="M75 90L${x} ${y}M${x-7*Math.cos(angle-.4)} ${y-7*Math.sin(angle-.4)}L${x} ${y}L${x-7*Math.cos(angle+.4)} ${y-7*Math.sin(angle+.4)}" fill="none" stroke="${color}" stroke-width="2"/>`}text+='</svg>'}return text+'</div>'}
function update(reset=false){const mode=$('mode').value,action=$('action').value,rows=data.modes[mode][action];$('time').max=rows.length-1;if(reset)$('time').value=0;const row=rows[+$('time').value];$('seconds').textContent=row[0].toFixed(3)+' s';$('hands').innerHTML=row[1].map((h,i)=>{const yaw=Math.atan2(h[3],h[5])*180/Math.PI,elevation=Math.atan2(h[4],Math.hypot(h[3],h[5]))*180/Math.PI;return `<tr><td>${i?'Right':'Left'}</td><td>${yaw.toFixed(1)}° / ${elevation.toFixed(1)}°</td><td>${fmt(h.slice(6,9))}</td><td>${fmt(h.slice(9,12))}</td></tr>`}).join('');$('diagrams').innerHTML=row[1].map((h,i)=>diagram(h,i?'Right':'Left')).join('');$('crossings').innerHTML=row[2].length?'<table><tr><th>Pair</th><th>Triangle pairs</th><th>Largest span</th></tr>'+row[2].map(c=>`<tr><td>${c[0]}</td><td>${c[1]}</td><td>${c[2].toFixed(3)}</td></tr>`).join('')+'</table>':'No non-coplanar surface crossings found in this sample.';if(reset){$('photos').innerHTML='';for(const photo of data.photos.filter(p=>p.action===action&&p.mode===mode)){const figure=document.createElement('figure'),image=document.createElement('img'),caption=document.createElement('figcaption');image.src=photo.src;image.alt=photo.title;caption.textContent=photo.title+' ('+photo.time.toFixed(3)+' s)';figure.append(image,caption);figure.onclick=()=>{let best=0;rows.forEach((r,i)=>{if(Math.abs(r[0]-photo.time)<Math.abs(rows[best][0]-photo.time))best=i});$('time').value=best;update()};$('photos').append(figure)}}}
$('action').onchange=$('mode').onchange=()=>update(true);$('time').oninput=()=>update();update(true);
</script></html>'''.replace('PAYLOAD', payload)
(out / 'viewer.html').write_text(html)
print(json.dumps(metrics, indent=2))
