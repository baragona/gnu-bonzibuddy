"""Bake a static subdivided source-pose preview; preserve scene.json for rig work."""
import json, math, struct, argparse
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
scene=json.loads((ROOT/'References/CandidateModel/scene.json').read_text())
parser=argparse.ArgumentParser();parser.add_argument('--morph');parser.add_argument('--output',type=Path);parser.add_argument('--parts',choices=['body','teeth'],default='body')
args=parser.parse_args();asset_dir=args.output or ROOT/'References/CandidateModel';asset_dir.mkdir(parents=True,exist_ok=True)
if args.morph:
 found=False
 for obj in scene['objects']:
  for tag in obj['tags']:
   for target in tag.get('morphs',[]):
    if target['name'].strip()==args.morph:
     obj['points']=target['points'];found=True
 if not found:raise ValueError('Unknown morph: '+args.morph)
def add(a,b):return tuple(x+y for x,y in zip(a,b))
def mul(a,s):return tuple(x*s for x in a)
def avg(ps):return mul(tuple(map(sum,zip(*ps))),1/len(ps))
def sub(a,b):return add(a,mul(b,-1))
def cross(a,b):return (a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0])
def subdivide(points,faces,colors):
 fp=[avg([points[v] for v in f]) for f in faces];edges={};vf=[[] for _ in points];ve=[set() for _ in points]
 for fi,f in enumerate(faces):
  for i,a in enumerate(f):
   b=f[(i+1)%len(f)];e=tuple(sorted((a,b)));edges.setdefault(e,[]).append(fi);vf[a].append(fi);ve[a].add(e);ve[b].add(e)
 out=[]
 for v,p in enumerate(points):
  boundary=[e for e in ve[v] if len(edges[e])==1]
  if len(boundary)==2:
   neighbors=[points[e[1] if e[0]==v else e[0]] for e in boundary]
   out.append(add(mul(p,.75),mul(add(*neighbors),.125)))
  elif vf[v]:
   n=len(vf[v]);F=avg([fp[i] for i in vf[v]]);R=avg([avg([points[e[0]],points[e[1]]]) for e in ve[v]])
   out.append(mul(add(add(F,mul(R,2)),mul(p,n-3)),1/n))
  else:out.append(p)
 edgeids={}
 for e,fs in edges.items():
  assert len(fs)<=2, ('Nonmanifold edge',e)
  edgeids[e]=len(out);out.append(avg([points[e[0]],points[e[1]]]+([fp[i] for i in fs] if len(fs)==2 else [])))
 start=len(out);out.extend(fp);newfaces=[];newcolors=[]
 for fi,f in enumerate(faces):
  for i,a in enumerate(f):
   newfaces.append([a,edgeids[tuple(sorted((a,f[(i+1)%len(f)])))],start+fi,edgeids[tuple(sorted((f[i-1],a)))]])
   newcolors.append(colors[fi])
 return out,newfaces,newcolors
palette={5:(.16,.065,.23,1),6:(.757,.620,.889,1),7:(.95,.94,.91,1),8:(.58,.33,.74,1),9:(.53,.305,.76,1)}
allpoints=[];allfaces=[];allcolors=[];alluv=[];alleyes=[];allweights=[];allparts=[]
for obj in scene['objects']:
 if 'points' not in obj:continue
 if args.parts=='body' and obj['name'] not in ('head','mouth','Sphere.1','eye'):continue
 if args.parts=='teeth' and obj['id'] not in (62,63):continue
 weights=next((t['joints'] for t in obj['tags'] if 'joints' in t),[{'object':56,'weights':[1]*len(obj['points'])}])
 weightmap={j['object']:j['weights'] for j in weights}
 points=[tuple(p)+tuple(weightmap[j][i] if j in weightmap else 0 for j in range(len(scene['objects']))) for i,p in enumerate(obj['points'])];faces=obj['faces'];colors=[palette[9]]*len(faces)
 selections={t['name']:t['faces'] for t in obj['tags'] if t['type']==5673}
 for tag in obj['tags']:
  if 'material' not in tag:continue
  color=palette.get(tag['material'],(1,0,0,1))
  if obj['name']=='eye':color=palette[7]
  if obj['name']=='mouth' and tag['material']==6:color=(.94,.78,1.07,1)
  for fi in selections[tag['selection']] if tag['selection'] else range(len(faces)):colors[fi]=color
 uv=list(next(t['uvw'] for t in obj['tags'] if 'uvw' in t))
 if obj['name']=='eye':
  # C4D texture tags use the following UVW tag; the eyes have distinct maps.
  for ti,t in enumerate(obj['tags']):
   if t.get('material')!=5:continue
   mapping=next(x['uvw'] for x in obj['tags'][ti+1:] if 'uvw' in x)
   for fi in selections[t['selection']]:uv[fi]=mapping[fi]
 uv=[[tuple(p) for p in face[:len(faces[i])]] for i,face in enumerate(uv)]
 for _ in range(2):
  newuv=[]
  for f in uv:
   centeruv=avg(f)
   for i,a in enumerate(f):newuv.append([a,avg([a,f[(i+1)%len(f)]]),centeruv,avg([f[i-1],a])])
  points,faces,colors=subdivide(points,faces,colors);uv=newuv
 alluv.extend(uv);alleyes.extend([obj['name']=='eye']*len(faces));allparts.extend([1 if obj['id']==62 else 2 if obj['id']==63 else 0]*len(faces))
 allweights.extend([p[3:] for p in points])
 points=[p[:3] for p in points]
 m=obj['worldMatrix'];points=[tuple(sum(m[j][i]*p[j] for j in range(3))+m[3][i] for i in range(3)) for p in points]
 offset=len(allpoints);allpoints.extend(points);allfaces.extend([[v+offset for v in f] for f in faces]);allcolors.extend(colors)
lo=[min(p[i] for p in allpoints) for i in range(3)];hi=[max(p[i] for p in allpoints) for i in range(3)];scale=2.05/(hi[1]-lo[1]);center=(lo[2]+hi[2])/2
if args.morph or args.parts!='body':
 baseline=json.loads((ROOT/'Resources/FanModel/FanRig.json').read_text())
 scale=baseline['scale'];lo[1]=baseline['sourceFloor'];center=baseline['sourceCenterZ']
# C4D model faces -Z. Rotate 180 degrees about Y, retaining handedness.
points=[(-p[0]*scale,(p[1]-lo[1])*scale-.90,-(p[2]-center)*scale) for p in allpoints]
normals=[(0,0,0) for _ in points];triangles=[];colors=[];triuv=[];trieyes=[];triparts=[]
for f,col,uv,eye,part in zip(allfaces,allcolors,alluv,alleyes,allparts):
 for i in range(1,len(f)-1):
  tri=(f[0],f[i],f[i+1]);a,b,c=[points[v] for v in tri];n=cross(sub(b,a),sub(c,a))
  for v in tri:normals[v]=add(normals[v],n)
  triangles.append(tri);colors.append(col);triuv.append([uv[0],uv[i],uv[i+1]]);trieyes.append(eye);triparts.append(part)
normals=[mul(n,1/max(1e-20,math.sqrt(sum(v*v for v in n)))) for n in normals]
vertices=[];rigvertices=[];indices=[];lookup={};discarded=[]
for tri,col,uv,eye,part in zip(triangles,colors,triuv,trieyes,triparts):
 for v,tex in zip(tri,uv):
  key=(v,col,tex if eye else None)
  if key not in lookup:
   lookup[key]=len(vertices);p=(*points[v],1);n=(*normals[v],tex[0] if eye else 0);n1=(*normals[v],tex[1] if eye else 0);vertices.append((*p,*n,*p,*n1,*col,0,0,2 if eye else 1,0))
   influence=sorted(enumerate(allweights[v]),key=lambda pair:pair[1],reverse=True)
   selected=influence[:8];total=sum(max(0,w) for _,w in selected)
   assert total>0
   discarded.append(sum(max(0,w) for _,w in influence[8:]))
   rigvertices.append((*p,*normals[v],0,*col,tex[0],tex[1],1 if eye else 0,part,*(float(j) for j,_ in selected),*(max(0,w)/total for _,w in selected)))
  indices.append(lookup[key])
out=asset_dir/'FanPreview.mesh'
with out.open('wb') as f:
 f.write(struct.pack('<5I',0x424F4E5A,3,len(vertices),len(indices),96))
 for v in vertices:f.write(struct.pack('<24f',*v))
 f.write(struct.pack('<%dI'%len(indices),*indices))
print(json.dumps({'vertices':len(vertices),'triangles':len(indices)//3,'sourceBounds':[lo,hi],'scale':scale,'subdivisionLevels':2,'pose':'source static control mesh','palette':'approved procedural baseline'},indent=2))

with (asset_dir/'FanRigged.mesh').open('wb') as f:
 f.write(struct.pack('<5I',0x424F4E5A,4,len(rigvertices),len(indices),128))
 for v in rigvertices:f.write(struct.pack('<32f',*v))
 f.write(struct.pack('<%dI'%len(indices),*indices))
rig={'version':1,'scale':scale,'sourceFloor':lo[1],'sourceCenterZ':center,'nodes':[{'id':o['id'],'parent':o['parent'],'name':o['name'],'worldMatrix':o['worldMatrix']} for o in scene['objects']], 'maxDiscardedWeight':max(discarded),'averageDiscardedWeight':sum(discarded)/len(discarded)}
(asset_dir/'FanRig.json').write_text(json.dumps(rig,indent=2)+'\n')
