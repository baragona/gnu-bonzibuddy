"""Validate the packed native asset against the exported joint hierarchy."""
import json,math,struct
from pathlib import Path
root=Path(__file__).resolve().parents[1]/'Resources/FanModel'
data=(root/'FanRigged.mesh').read_bytes();magic,version,nv,ni,stride=struct.unpack_from('<5I',data)
assert (magic,version,stride)==(0x424F4E5A,4,128)
assert len(data)==20+nv*stride+ni*4
rig=json.loads((root/'FanRig.json').read_text());max_error=0;min_normal=1;max_normal=0
for v in struct.iter_unpack('<32f',data[20:20+nv*stride]):
 assert all(math.isfinite(x) for x in v)
 assert all(j==int(j) and 0<=j<len(rig['nodes']) for j in v[16:24])
 assert all(0<=w<=1 for w in v[24:32])
 max_error=max(max_error,abs(sum(v[24:32])-1))
 normal=math.sqrt(sum(x*x for x in v[4:7]));min_normal=min(min_normal,normal);max_normal=max(max_normal,normal)
assert max_error<1e-6
assert min_normal>.99 and max_normal<1.01
assert all(i<nv for (i,) in struct.iter_unpack('<I',data[20+nv*stride:]))
print(json.dumps({'vertices':nv,'triangles':ni//3,'maxWeightNormalizationError':max_error,'normalLengthRange':[min_normal,max_normal],'maxDiscardedSourceWeight':rig['maxDiscardedWeight'],'averageDiscardedSourceWeight':rig['averageDiscardedWeight']},indent=2))
