"""Subdivide source facial targets identically to the neutral mesh and pack GPU deltas."""
import json,struct,subprocess,sys,math
from pathlib import Path
root=Path(__file__).resolve().parents[1];assets=root/'Resources/FanModel';research=root/'References/CandidateModel'
scene=json.loads((research/'scene.json').read_text())
names=['smile','jaw','eyebrow up']
for obj in scene['objects']:
 for tag in obj['tags']:
  for morph in tag.get('morphs',[])[1:]:
   name=morph['name'].strip()
   if name not in names:names.append(name)
assert len(names)<=16
folders={name:name.replace(' ','-').replace('/','-').replace('?', 'brow-variant-1').replace('¿','brow-variant-2') for name in names}
base=(assets/'FanRigged.mesh').read_bytes();header=struct.unpack_from('<5I',base);count=header[2];stride=header[4]
basevertices=list(struct.iter_unpack('<32f',base[20:20+count*stride]))
output=bytearray(struct.pack('<4I',0x424D4F52,1,count,len(names)));report=[]
for name in names:
 folder=research/'MorphVariants'/folders[name]
 subprocess.run([sys.executable,str(root/'Scripts/convert-fan-preview.py'),'--morph',name,'--output',str(folder)],check=True,stdout=subprocess.DEVNULL)
 target=(folder/'FanRigged.mesh').read_bytes()
 assert struct.unpack_from('<5I',target)==header
 assert target[20+count*stride:]==base[20+count*stride:],'Morph changed topology'
 maxdelta=0;changed=0
 for a,b in zip(basevertices,struct.iter_unpack('<32f',target[20:20+count*stride])):
  assert a[8:]==b[8:],'Morph changed material, UV, joint or weight data'
  delta=[b[i]-a[i] for i in range(8)]
  assert all(math.isfinite(x) for x in delta)
  length=math.sqrt(sum(x*x for x in delta[:3]));maxdelta=max(maxdelta,length)
  if length>1e-7:changed+=1
  output.extend(struct.pack('<8f',*delta))
 report.append({'name':name,'folder':folders[name],'changedVertices':changed,'maximumPositionDelta':maxdelta})
(assets/'FanMorphs.bin').write_bytes(output)
(assets/'FanMorphs.json').write_text(json.dumps({'version':1,'names':names,'vertices':count,'targets':report},indent=2)+'\n')
print(json.dumps(report,indent=2))
