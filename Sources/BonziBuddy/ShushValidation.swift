import MetalKit
import simd

func validateShush() throws {
    let triangle=AuditTriangle(a:[0,0,0],b:[1,0,0],c:[0,1,0])
    guard length(triangle.closestPoint(to:[0.2,0.2,1])-[0.2,0.2,0])<1e-6,
          length(triangle.closestPoint(to:[2,0,0])-[1,0,0])<1e-6 else {throw failure("Closest-point geometry fixture failed")}
    guard let device=MTLCreateSystemDefaultDevice() else {throw failure("Metal unavailable")}
    var rows:[[String:Any]]=[],targetError:Float=0,headGap:Float=0,footDrift:Float=0
    var automaticPucker:Float=0,overriddenPucker:Float=0
    for yaw in [Float(0),-Float.pi/4,-Float.pi/2] {
        let renderer=try Renderer(device:device,previewMesh:URL(fileURLWithPath:"Resources/FanModel/FanRigged.mesh"),rigURL:URL(fileURLWithPath:"Resources/FanModel/FanRig.json"))
        renderer.fanLiveActions=true;renderer.fanTeethEnabled=true;renderer.character.yaw=yaw
        renderer.character.play(.shush,at:0)
        let rig=renderer.fanRig!,gpu=try AuditGPU(renderer),ptr=renderer.vertices.contents()
        let isHead=(0..<Int(renderer.fanMorphVertexCount)).map {i -> Bool in
            var weight:Float=0
            for lane in 0..<8 {
                let joint=Int(ptr.load(fromByteOffset:i*128+(16+lane)*4,as:Float.self))
                if joint>=55 {weight+=ptr.load(fromByteOffset:i*128+(24+lane)*4,as:Float.self)}
            }
            return weight>0.5
        }
        let faces=stride(from:0,to:renderer.indexCount,by:3).compactMap {i -> SIMD3<Int>? in
            let ids=SIMD3<Int>((0..<3).map {Int(renderer.indices.contents().load(fromByteOffset:(i+$0)*4,as:UInt32.self))})
            return isHead[ids.x] && isHead[ids.y] && isHead[ids.z] ? ids:nil
        }
        guard faces.count>100 else {throw failure("Missing head surface geometry")}
        var captured:AuditFrame?,first:[Instance]=[]
        renderer.onAuditFrame={captured=AuditFrame(bones:$0,props:$1,morphs:$2)}
        for frame in 0...234 {
            let t=Double(frame)/120
            _=try renderer.offscreen(width:160,height:128,at:t)
            let snapshot=captured!,bones=snapshot.bones
            if first.isEmpty {first=bones}
            for joint in [14,15,18,19] {for c in 0..<4 {footDrift=max(footDrift,length(first[joint].model[c]-bones[joint].model[c]))}}
            if [60,96,132,168].contains(frame) {
                let marker=rig.attachmentFrame(.indexTip(.left),axes:.character,bones:bones).columns.3
                let tip=SIMD3(marker.x,marker.y,marker.z)
                let desired=bones[0].model*SIMD4<Float>(rig.routine.hands[.left]!.indexTipContact!,1)
                let error=length(marker-desired)
                let (points,_)=try gpu.positions(snapshot)
                var distance=Float.infinity,nearest=SIMD3<Float>.zero
                for ids in faces {
                    let candidate=AuditTriangle(a:points[ids.x],b:points[ids.y],c:points[ids.z]).closestPoint(to:tip)
                    let gap=length(tip-candidate)
                    if gap<distance {distance=gap;nearest=candidate}
                }
                targetError=max(targetError,error);headGap=max(headGap,distance)
                rows.append(["tip":[tip.x,tip.y,tip.z],"nearestHead":[nearest.x,nearest.y,nearest.z],"yaw":yaw,"time":t,"indexTargetError":error,"indexTipToHeadSurfaceDistance":distance,"mouthPucker":snapshot.morphs.weights.2.w])
            }
        }
        renderer.character.play(.shush,at:2)
        _=try renderer.offscreen(width:160,height:128,at:2)
        _=try renderer.offscreen(width:160,height:128,at:2.6)
        automaticPucker=captured!.morphs.weights.2.w
        renderer.fanExpressionOverrides[11]=0.7
        _=try renderer.offscreen(width:160,height:128,at:2.61)
        overriddenPucker=captured!.morphs.weights.2.w
        guard abs(automaticPucker-0.22)<1e-5,abs(overriddenPucker-0.7)<1e-5 else {throw failure("Automatic pucker or manual override failed")}
    }
    let report:[String:Any]=["samples":705,"contactViews":rows,"maximumIndexTargetError":targetError,"maximumTipToHeadSurfaceDistance":headGap,"maximumFootMatrixDrift":footDrift,"automaticPucker":automaticPucker,"manualPuckerOverride":overriddenPucker,"note":"Head proximity uses actual Metal-morphed triangles. A distance bound does not prove lip contact or nonpenetration; separate whole-hand geometry scans and visual review are required."]
    try FileManager.default.createDirectory(atPath:"Validation/Shush",withIntermediateDirectories:true)
    let data=try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys])
    try data.write(to:URL(fileURLWithPath:"Validation/Shush/checks.json"));print(String(decoding:data,as:UTF8.self))
    guard targetError<0.006,headGap<0.035,footDrift<1e-5 else {throw failure("Shush contact or foot-placement error")}
}
