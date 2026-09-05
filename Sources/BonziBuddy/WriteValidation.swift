import Foundation
import simd

func validateWrite() throws {
    var vertices=0,triangles=0
    for kind in [PropKind.writingPad,.pencil] {
        let mesh=WritingGeometry.mesh(kind)
        for i in stride(from:0,to:mesh.1.count,by:3) {
            let v=(0..<3).map {mesh.0[Int(mesh.1[i+$0])]}
            let p=v.map {SIMD3<Float>($0.position.x,$0.position.y,$0.position.z)}
            let n=cross(p[1]-p[0],p[2]-p[0])
            guard length(n)>1e-10,dot(n,SIMD3(v[0].normal.x,v[0].normal.y,v[0].normal.z))>0 else {throw failure("Invalid writing prop triangle")}
        }
        vertices += mesh.0.count;triangles += mesh.1.count/3
    }
    var tipError:Float=0
    for frame in 0...60 {
        let t=2.20+Double(frame)*0.5/60,pose=WriteRoutine.sample(at:t)
        let pad=pose.props.first {$0.kind == .writingPad}!,pencil=pose.props.first {$0.kind == .pencil}!
        guard case let .transformed(_,origin,rotation)=pad.anchor else {throw failure("Pad frame missing")}
        let local=rotation.inverse.act(pencil.offset-origin)
        tipError=max(tipError,abs(local.z-WritingGeometry.paperZ-0.002))
        guard abs(local.x)<0.285,abs(local.y)<0.205 else {throw failure("Pencil leaves writing surface")}
    }
    guard tipError<0.00001 else {throw failure("Pencil tip lost pad contact")}
    let start=WriteRoutine.sample(at:4.30),end=WriteRoutine.sample(at:5.50)
    for side in HandSide.allCases {
        guard length(start.hands[side]!.wrist-end.hands[side]!.wrist)<0.00001 else {throw failure("Writing loop hand jump")}
    }
    guard length(start.props[1].offset-end.props[1].offset)<0.00001 else {throw failure("Writing loop pencil jump")}
    var player=CharacterPlayback();player.play(.write,at:0,mode:.hold)
    player.request(.wave,at:4.70)
    guard player.playbackSnapshot(at:5.40).elapsed<5.50,player.playbackSnapshot(at:6.94).action == .write,player.playbackSnapshot(at:6.96).action == .wave else {throw failure("Writing handoff cut off stroke or stow")}
    let report:[String:Any]=["vertices":vertices,"triangles":triangles,"maximumPencilPlaneError":tipError,"contactSamples":61,"holdSeamPassed":true,"strokeAndStowHandoffPassed":true,"note":"Pencil contact is measured against the authored pad plane. These checks do not establish finger contact, full-body collision avoidance, or original visual identity."]
    try FileManager.default.createDirectory(atPath:"Validation/Writing",withIntermediateDirectories:true)
    let data=try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys])
    try data.write(to:URL(fileURLWithPath:"Validation/Writing/checks.json"));print(String(decoding:data,as:UTF8.self))
}
