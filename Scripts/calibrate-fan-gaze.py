import struct,math,hashlib,json,re
# Offline calibration of the imported fan eye maps; no runtime dependencies.
# The shader pupil center includes +0.035 in signed V and 0.20 gaze scale.
with open('Resources/FanModel/FanRigged.mesh','rb') as f:
 h=struct.unpack('<5I',f.read(20));v=[struct.unpack('<32f',f.read(128)) for _ in range(h[2])];ids=struct.unpack('<%dI'%h[3],f.read(h[3]*4))
faces=[]
for j in range(0,len(ids),3):
 a,b,c=[v[i] for i in ids[j:j+3]]
 if all(p[14]>.5 and p[6]>0 for p in [a,b,c]):faces.append((a,b,c))
def normal_yaw(side,gaze):
 u=.5+side*.2*gaze;w=.5+side*.035
 for a,b,c in faces:
  if a[0]*side<=0:continue
  ax,ay=a[12:14];bx,by=b[12:14];cx,cy=c[12:14];d=(by-cy)*(ax-cx)+(cx-bx)*(ay-cy)
  if abs(d)<1e-10:continue
  x=((by-cy)*(u-cx)+(cx-bx)*(w-cy))/d;y=((cy-ay)*(u-cx)+(ax-cx)*(w-cy))/d;z=1-x-y
  if min(x,y,z)>=-1e-5:
   nx=a[4]*x+b[4]*y+c[4]*z;nz=a[6]*x+b[6]*y+c[6]*z
   return math.atan2(nx*1.13,nz)
rows=[]
for angle in [0,.1,.2,.3,.4,.5]:
 values=[]
 for side in [1,-1]:
  base=normal_yaw(side,0);lo=0;hi=4.5 if side==1 else 2.2
  for _ in range(28):
   mid=(lo+hi)/2;n=normal_yaw(side,mid)
   if n is None or n-base>angle:hi=mid
   else:lo=mid
  values.append(round((hi+lo)/2,6))
 rows.append({'yawRadians':angle,'leftRightOffsets':values})

# Verify the committed runtime calibration against actual eye triangles.
runtime=[tuple(map(float,p)) for p in re.findall(r"\[([0-9.]+),([0-9.]+)\]",open("Sources/BonziBuddy/FanGazeCompensation.swift").read())]
assert len(runtime)==6
assert max(abs(a-b) for r,k in zip(rows,runtime) for a,b in zip(r['leftRightOffsets'],k))<1e-5
maximum_error=0
for step in range(101):
 angle=step*.005;index=min(4,int(angle*10));blend=angle*10-index
 for eye,side in enumerate([1,-1]):
  gaze=runtime[index][eye]+(runtime[index+1][eye]-runtime[index][eye])*blend
  error=abs(normal_yaw(side,gaze)-normal_yaw(side,0)-angle)
  maximum_error=max(maximum_error,error)
assert maximum_error<0.04, maximum_error
print(json.dumps({"meshSHA256":hashlib.sha256(open("Resources/FanModel/FanRigged.mesh","rb").read()).hexdigest(),"headScaleX":1.13,"rows":rows,"surfaceNormalSamples":202,"maximumAngularCompensationErrorRadians":maximum_error,"note":"Preserves each eye's neutral horizontal surface-normal direction through head yaw; not arbitrary camera-target tracking or a perceptual gaze guarantee."},indent=2))
