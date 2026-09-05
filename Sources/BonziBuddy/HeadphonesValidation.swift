import Foundation
import simd

func validateHeadphones() throws {
    let (vertices,indices)=HeadphonesGeometry.mesh()
    guard indices.count%3==0,indices.allSatisfy({Int($0)<vertices.count}) else {throw failure("Invalid headset indices")}
    var reversed=0,degenerate=0
    for vertex in vertices {
        guard (0..<4).allSatisfy({vertex.position[$0].isFinite && vertex.normal[$0].isFinite}),abs(length(SIMD3(vertex.normal.x,vertex.normal.y,vertex.normal.z))-1)<0.001 else {throw failure("Invalid headset vertex")}
    }
    for i in stride(from:0,to:indices.count,by:3) {
        let v=(0..<3).map {vertices[Int(indices[i+$0])]}
        let p=v.map {SIMD3($0.position.x,$0.position.y,$0.position.z)}
        let crossProduct=cross(p[1]-p[0],p[2]-p[0])
        if length(crossProduct)<1e-12 {degenerate+=1}
        let n=v[0].normal+v[1].normal+v[2].normal
        if dot(crossProduct,SIMD3(n.x,n.y,n.z))<=0 {reversed+=1}
    }
    guard reversed==0,degenerate==0 else {throw failure("Headset has reversed or degenerate triangles: \(reversed), \(degenerate)")}
    let rig=try FanRig(url:URL(fileURLWithPath:"Resources/FanModel/FanRig.json")),motion=PropMotion()
    var headError:Float=0,gripError:Float=0
    for frame in 0...Int(HeadphonesRoutine.duration*120) {
        let t=Double(frame)/120
        rig.updateLiveAction(.headphones,started:0,at:t,elapsed:t)
        let bones=rig.instances(yaw:-0.65,pitch:0.18,at:t)
        let draws=motion.sample(action:.headphones,started:0,at:t,cues:rig.routine.props,rig:rig,bones:bones)
        for draw in draws {
            if t>=2 && t<=12.02 {
                let expected=rig.attachmentFrame(.head,axes:.joint,bones:bones)
                for c in 0..<4 {for r in 0..<4 {headError=max(headError,abs(draw.model[c][r]-expected[c][r]))}}
            }
            if t>=0.8 && t<=1.3 {
                for side in [HandSide.left,.right] {
                    let marker=draw.model*SIMD4<Float>(side.sign*0.505,0.245,0.085,1)
                    let hand=rig.attachmentFrame(.wrist(side),axes:.character,bones:bones).columns.3
                    gripError=max(gripError,length(marker-hand))
                }
            }
        }
    }
    guard headError<0.00001,gripError<0.03 else {throw failure("Headset attachment error: head \(headError), grip \(gripError)")}
    var playback=CharacterPlayback()
    playback.setSunglassesEnabled(true,at:0)
    playback.play(.headphones,at:3,mode:.hold)
    guard playback.wearsSunglasses(at:20),playback.playbackSnapshot(at:20).action == .headphones else {throw failure("Headphones cannot combine with sunglasses")}
    playback.setSunglassesEnabled(false,at:20)
    guard playback.playbackSnapshot(at:20.5).action == .headphones,playback.wearsSunglasses(at:20.5) else {throw failure("Headphones return was interrupted")}
    guard playback.playbackSnapshot(at:22.2).action == .sunglasses,!playback.wearsSunglasses(at:24.1) else {throw failure("Held headphones blocked accessory removal")}
    let report:[String:Any]=["vertices":vertices.count,"triangles":indices.count/3,"reversedTriangles":reversed,"degenerateTriangles":degenerate,"maximumHeadAttachmentError":headError,"maximumCarryGripError":gripError,"sunglassesCombinationAndOrderedReturnPassed":true,"note":"Geometry orientation and attachment checks, not proof of fingertip contact, headband clearance, or original visual fidelity."]
    try FileManager.default.createDirectory(atPath:"Validation/Headphones",withIntermediateDirectories:true)
    let data=try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys])
    try data.write(to:URL(fileURLWithPath:"Validation/Headphones/checks.json"));print(String(decoding:data,as:UTF8.self))
}
