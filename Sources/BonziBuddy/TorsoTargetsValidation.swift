import MetalKit
import simd

func validateTorsoTargets() throws {
    guard let device=MTLCreateSystemDefaultDevice() else {throw failure("Metal unavailable")}
    let renderer=try Renderer(device:device,previewMesh:URL(fileURLWithPath:"Resources/FanModel/FanRigged.mesh"),rigURL:URL(fileURLWithPath:"Resources/FanModel/FanRig.json"))
    renderer.fanLiveActions=true;renderer.character.play(.hug,at:0)
    let gpu=try AuditGPU(renderer),ptr=renderer.vertices.contents()
    let indices=(0..<Int(renderer.fanMorphVertexCount)).filter {i in
        var influenced=false
        for lane in 0..<8 {
            let weight=ptr.load(fromByteOffset:i*128+(24+lane)*4,as:Float.self)
            if weight>0 {
                influenced=true
                let joint=Int(ptr.load(fromByteOffset:i*128+(16+lane)*4,as:Float.self))
                if !(24...38).contains(joint) && !(41...54).contains(joint) {return false}
            }
        }
        return influenced
    }
    // This asset has only nine vertices with exclusively hand-joint weights.
    // The others retain small torso/head/arm influences. Check those nine GPU
    // vertices plus every hand-joint transform; mixed skin is covered by the scan.
    guard !indices.isEmpty else {throw failure("Missing pure hand vertices for torso-target validation")}
    let joints=Array(24...38)+Array(41...54)
    var frame:AuditFrame?,baseline:[SIMD3<Float>]=[],baselineJoints:[simd_float4x4]=[],maximum:Float=0,matrixMaximum:Float=0
    renderer.onAuditFrame={frame=AuditFrame(bones:$0,props:$1,morphs:$2)}
    _=try renderer.offscreen(width:160,height:128,at:0)
    let times=[0.8,1.32,1.68,2.04,2.8]
    for time in times {
        _=try renderer.offscreen(width:160,height:128,at:time)
        let captured=frame!,points=try gpu.positions(captured).0,inverse=captured.bones[21].model.inverse
        let local=indices.map {i -> SIMD3<Float> in let p=inverse*SIMD4(points[i],1);return SIMD3(p.x,p.y,p.z)}
        if baseline.isEmpty {baseline=local}
        for i in local.indices {maximum=max(maximum,length(local[i]-baseline[i]))}
        let matrices=joints.map {inverse*captured.bones[$0].model}
        if baselineJoints.isEmpty {baselineJoints=matrices}
        for i in matrices.indices {for c in 0..<4 {for r in 0..<4 {
            matrixMaximum=max(matrixMaximum,abs(matrices[i][c][r]-baselineJoints[i][c][r]))
        }}}
    }
    guard maximum<0.0001,matrixMaximum<0.0001 else {throw failure("Hands drift in the torso frame during a held embrace: vertices \(maximum), joints \(matrixMaximum)")}
    let report:[String:Any]=["samples":times,"pureHandVertices":indices.count,"handJoints":joints.count,"maximumTorsoRelativeHandDrift":maximum,"maximumTorsoRelativeJointDrift":matrixMaximum,"note":"All hand-joint matrices and the actual Metal-deformed vertices with exclusively hand-joint weights, mapped back through the torso transform during the fixed-contact Hug hold. Other hand vertices have small non-hand skin influences and remain covered by the full mesh scan. Does not establish collision avoidance or original likeness."]
    try FileManager.default.createDirectory(atPath:"Validation/TorsoTargets",withIntermediateDirectories:true)
    let data=try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys])
    try data.write(to:URL(fileURLWithPath:"Validation/TorsoTargets/checks.json"))
    print(String(decoding:data,as:UTF8.self))
}
