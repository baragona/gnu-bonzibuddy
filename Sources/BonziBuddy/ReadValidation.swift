import Foundation
import simd

func validateRead() throws {
    var verticesCount=0,trianglesCount=0
    for kind in [PropKind.bookLeft,.bookRight,.bookLeaf] {
        let (vertices,indices)=BookGeometry.mesh(kind)
        for curl:Float in kind == .bookLeaf ? [0,0.5,1]:[0] {
            for i in stride(from:0,to:indices.count,by:3) {
                let v=(0..<3).map {vertices[Int(indices[i+$0])]}
                let p=v.map {v -> SIMD3<Float> in
                    let p=v.position+(v.openedPosition-v.position)*curl
                    return SIMD3(p.x,p.y,p.z)
                }
                let normal=cross(p[1]-p[0],p[2]-p[0])
                let n=v.reduce(SIMD4<Float>.zero) {$0+$1.normal+($1.openedNormal-$1.normal)*curl}
                guard length(normal)>1e-12,dot(normal,SIMD3(n.x,n.y,n.z))>0 else {throw failure("Invalid book/page topology")}
            }
        }
        verticesCount+=vertices.count;trianglesCount+=indices.count/3
    }
    let rig=try FanRig(url:URL(fileURLWithPath:"Resources/FanModel/FanRig.json")),mesh=try FanMeshData(url:URL(fileURLWithPath:"Resources/FanModel/FanRigged.mesh"))
    struct FootSample {let p:SIMD4<Float>;let bones:[Int];let weights:[Float]}
    var feet:[FootSample]=[]
    for i in 0..<(mesh.vertices.count/128) {
        let v=(0..<32).map {c in mesh.vertices.withUnsafeBytes {$0.loadUnaligned(fromByteOffset:i*128+c*4,as:Float.self)}}
        let indices=(0..<8).map {Int(v[16+$0])},weights=Array(v[24..<32])
        let footWeight=(0..<8).filter {[14,15,18,19].contains(indices[$0])}.reduce(Float(0)) {$0+weights[$1]}
        if footWeight>0.8 {feet.append(FootSample(p:[v[0],v[1],v[2],1],bones:indices,weights:weights))}
    }
    guard feet.count>100 else {throw failure("Missing foot surface samples")}
    var ankleError:Float=0,minimumFootY:Float=100,seatedFootY:Float=100
    for frame in 0...Int(ReadRoutine.duration*120) {
        let t=Double(frame)/120
        rig.updateLiveAction(.read,started:0,at:t,elapsed:t)
        let bones=rig.instances(yaw:0,pitch:0,at:t)
        if t>=0.65 && t<=10.70 {
            for (side,joint) in [(FootSide.left,14),(.right,18)] {
                let p=bones[0].model.inverse*bones[joint].model*rig.rest[joint].columns.3
                ankleError=max(ankleError,length(SIMD3(p.x,p.y,p.z)-rig.routine.stance.feet[side]!.ankle))
            }
        }
        if frame%8==0 {
            for point in feet {
                var world=SIMD4<Float>.zero
                for i in 0..<8 where point.weights[i]>0 {world += (bones[point.bones[i]].model*point.p)*point.weights[i]}
                minimumFootY=min(minimumFootY,world.y)
                if t>=2 && t<=9 {seatedFootY=min(seatedFootY,world.y)}
            }
        }
    }
    var player=CharacterPlayback();player.play(.read,at:0,mode:.hold)
    guard player.playbackSnapshot(at:30).action == .read else {throw failure("Reading did not hold")}
    player.finishRoutine(at:30)
    guard player.playbackSnapshot(at:32.57).action == .read,player.playbackSnapshot(at:33.6).action == .idle else {throw failure("Reading did not return")}
    var interrupted=CharacterPlayback();interrupted.play(.read,at:0,mode:.hold)
    interrupted.setHeadphonesEnabled(true,at:15)
    guard interrupted.playbackSnapshot(at:15.5).action == .read,interrupted.playbackSnapshot(at:17.7).action == .headphones else {throw failure("Accessory transfer skipped book stow")}
    var requested=CharacterPlayback();requested.play(.read,at:0,mode:.hold)
    requested.request(.wave,at:10)
    guard requested.playbackSnapshot(at:10.5).action == .read,requested.playbackSnapshot(at:12.6).action == .wave else {throw failure("Menu action skipped book stow/stand")}
    requested.request(.dance,at:10.5)
    guard requested.playbackSnapshot(at:12.6).action == .dance else {throw failure("Latest queued action was lost")}
    var turning=CharacterPlayback();turning.play(.read,at:0,mode:.hold)
    turning.request(.wave,at:6.3)
    guard turning.playbackSnapshot(at:6.8).elapsed<9.05,turning.playbackSnapshot(at:9.7).action == .read,turning.playbackSnapshot(at:9.8).action == .wave else {throw failure("Page turn was cut off before stow")}
    guard minimumFootY>=(-0.925),abs(seatedFootY+0.92)<0.015 else {throw failure("Seated feet float or intersect the floor: \(minimumFootY), \(seatedFootY)")}
    guard ankleError<0.00001 else {throw failure("Seated feet lost their targets")}
    let report:[String:Any]=["vertices":verticesCount,"triangles":trianglesCount,"footSurfaceSamples":feet.count,"maximumSeatedAnkleError":ankleError,"minimumFootY":minimumFootY,"minimumSeatedFootY":seatedFootY,"groundY":-0.92,"pageTurnCompletedBeforeReturn":true,"menuRequestWaitedForStand":true,"heldAndRequestedReturnPassed":true,"accessoryWaitedForStow":true,"note":"Foot surface heights are sampled diagnostics. These checks do not establish full-body collision avoidance or original choreography fidelity."]
    try FileManager.default.createDirectory(atPath:"Validation/Read",withIntermediateDirectories:true)
    let data=try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]);try data.write(to:URL(fileURLWithPath:"Validation/Read/checks.json"));print(String(decoding:data,as:UTF8.self))
}
