"""Export the fan model's existing glasses into the shared indexed prop format."""
import json, math, struct
from pathlib import Path
root=Path(__file__).resolve().parents[1]
scene=json.loads((root/'References/CandidateModel/scene.json').read_text())
rig=json.loads((root/'Resources/FanModel/FanRig.json').read_text())
obj=next(o for o in scene['objects'] if o['name']=='Glasses')
s=rig['scale'];floor=rig['sourceFloor'];cz=rig['sourceCenterZ']
def converted(p):return (-p[0]*s,(p[1]-floor)*s-.9,-(p[2]-cz)*s)
head=converted(scene['objects'][56]['worldMatrix'][3])
points=[]
for p in obj['points']:
 m=obj['worldMatrix'];world=[sum(m[j][i]*p[j]for j in range(3))+m[3][i]for i in range(3)]
 x,y,z=converted(world)
 # Match the approved upper-face lift and head shape, then store relative to its pivot.
 if .48<y<1.25:
  t=(y-.48)/.20 if y<.68 else (1.25-y)/.35 if y>.9 else 1
  y+=.1*t*t*(3-2*t)
 points.append(((x-head[0])*1.13,(y-head[1])*.93,z-head[2]))
lenses=set(next(t['faces']for t in obj['tags']if t.get('name')=='Polygon Selection #1'))
normals=[[0.,0.,0.]for p in points];triangles=[]
for fi,face in enumerate(obj['faces']):
 face=list(dict.fromkeys(face))
 for i in range(1,len(face)-1):
  tri=(face[0],face[i],face[i+1]);a,b,c=[points[j]for j in tri]
  u=[b[j]-a[j]for j in range(3)];v=[c[j]-a[j]for j in range(3)]
  n=[u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]]
  if sum(q*q for q in n)<1e-20:continue
  for j in tri:
   for k in range(3):normals[j][k]+=n[k]
  triangles.append((tri,1 if fi in lenses else 0))
vertices=[];indices=[];lookup={}
for tri,material in triangles:
 for j in tri:
  key=j,material
  if key not in lookup:
   lookup[key]=len(vertices);p=points[j];n=normals[j];length=math.sqrt(sum(q*q for q in n));assert length>1e-12
   vertices.append((*p,1,*(q/length for q in n),0,0,0,0,float(material),0,0,0,0,0,0,0,0))
  indices.append(lookup[key])
path=root/'Resources/Props/FanSunglasses.mesh'
with path.open('wb')as f:
 f.write(struct.pack('<5I',0x42505250,1,len(vertices),len(indices),80))
 for v in vertices:f.write(struct.pack('<20f',*v))
 f.write(struct.pack('<%dI'%len(indices),*indices))
lens_points=[points[j]for tri,mat in triangles if mat for j in tri]
bounds=[(min(p[i]for p in points),max(p[i]for p in points))for i in range(3)]
print('Wrote',path.name,len(vertices),'vertices',len(indices)//3,'triangles; bounds',bounds)
print('Lens bounds',[(min(p[i]for p in lens_points),max(p[i]for p in lens_points))for i in range(3)])
print('Rest head pivot',head)
