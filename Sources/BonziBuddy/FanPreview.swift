import AppKit
import MetalKit
import simd

func previewFan() throws {
    guard let device=MTLCreateSystemDefaultDevice() else { throw failure("Metal GPU unavailable") }
    let renderer=try Renderer(device:device,previewMesh:URL(fileURLWithPath:"Resources/FanModel/FanRigged.mesh"),rigURL:URL(fileURLWithPath:"Resources/FanModel/FanRig.json"))
    let folder="Validation/FanRigged"
    try FileManager.default.createDirectory(atPath:folder,withIntermediateDirectories:true)
    renderer.fanMorphIndices=[2,1];renderer.fanMorphWeights=[1,0];renderer.fanExpressionOverrides=[0:0.2]
    for (name,yaw) in [("front",Float(0)),("left-quarter",-Float.pi/4),("left-side",-Float.pi/2),("rear",Float.pi),("right-quarter",Float.pi/4)] {
        renderer.character.yaw=yaw
        let (texture,_)=try renderer.offscreen(width:800,height:640,at:0)
        try writePNG(texture,to:"\(folder)/\(name).png")
    }
    renderer.fanMorphIndices=[0,1];renderer.fanMorphWeights=[0,0];renderer.fanExpressionOverrides.removeAll()
    let morphFolder="\(folder)/Morphs"
    try FileManager.default.createDirectory(atPath:morphFolder,withIntermediateDirectories:true)
    for (index,name) in ["smile","jaw","eyebrow-up"].enumerated() {
        renderer.fanMorphIndices=[UInt32(index),0]
        for (angle,yaw) in [("front",Float(0)),("quarter",-Float.pi/4),("left",-Float.pi/2)] {
            renderer.character.yaw=yaw
            for weight:Float in [0.5,1] {
                renderer.fanMorphWeights=[weight,0]
                let (texture,_)=try renderer.offscreen(width:800,height:640,at:0)
                try writePNG(texture,to:"\(morphFolder)/\(name)-\(angle)-\(Int(weight*100)).png")
            }
        }
        let endpoint=try Renderer(device:device,previewMesh:URL(fileURLWithPath:"References/CandidateModel/MorphVariants/\(name)/FanRigged.mesh"),rigURL:URL(fileURLWithPath:"Resources/FanModel/FanRig.json"))
        let (texture,_)=try endpoint.offscreen(width:800,height:640,at:0)
        try writePNG(texture,to:"\(morphFolder)/\(name)-baked.png")
    }
    renderer.fanMorphWeights=[0,0]
    renderer.character.yaw=0
    renderer.fanRig!.sourcePose=true
    let (sourceTexture,_)=try renderer.offscreen(width:800,height:640,at:0)
    try writePNG(sourceTexture,to:"\(folder)/source-pose.png")
    let matrices=renderer.fanRig!.instances(yaw:0,pitch:0,at:0)
    var bindError:Float=0
    for m in matrices {
        for c in 0..<4 { for r in 0..<4 { bindError=max(bindError,abs(m.model[c][r]-(c==r ? 1:0))) } }
    }
    guard bindError<0.0001 else { throw failure("Fan source pose did not preserve the bind geometry") }
    renderer.fanRig!.sourcePose=false
    var footTransformError:Float=0
    let rest=renderer.fanRig!.instances(yaw:0,pitch:0,at:0)
    for frame in 0..<240 {
        let pose=renderer.fanRig!.instances(yaw:0,pitch:0,at:Double(frame)/30)
        for bone in [12,13,14,15,16,17,18,19] {
            for c in 0..<4 { for r in 0..<4 { footTransformError=max(footTransformError,abs(pose[bone].model[c][r]-rest[bone].model[c][r])) } }
        }
    }
    guard footTransformError<0.000001 else { throw failure("Idle breathing moved fan leg joints") }
    // Measure the actual weighted foot surface, beyond the joint-only invariant.
    let mesh=try FanMeshData(url:URL(fileURLWithPath:"Resources/FanModel/FanRigged.mesh"))
    var footVertices:[(SIMD4<Float>,[Int],[Float])]=[]
    for index in 0..<(mesh.vertices.count/128) {
        let v:[Float]=(0..<32).map { c in mesh.vertices.withUnsafeBytes { $0.loadUnaligned(fromByteOffset:index*128+c*4,as:Float.self) } }
        let ids=v[16..<24].map(Int.init),weights=Array(v[24..<32])
        let footWeight=zip(ids,weights).filter { [14,15,18,19].contains($0.0) }.reduce(Float(0)) { $0+$1.1 }
        if v[1]<(-0.82) && footWeight>0.5 { footVertices.append((SIMD4(v[0],v[1],v[2],1),ids,weights)) }
    }
    guard !footVertices.isEmpty else { throw failure("No foot surface samples") }
    func footPositions(_ instances:[Instance])->[SIMD3<Float>] {
        footVertices.map { p,ids,weights in
            var world=SIMD4<Float>(repeating:0)
            for (id,w) in zip(ids,weights) { world+=(instances[id].model*p)*w }
            return SIMD3(world.x,world.y,world.z)
        }
    }
    let baseFeet=footPositions(rest)
    guard abs(baseFeet.map(\.y).min()! - (-0.92))<0.002 else { throw failure("Foot surface does not contact the ground plane") }
    var footVertexDrift:Float=0
    for frame in 0..<60 {
        let sample=footPositions(renderer.fanRig!.instances(yaw:0,pitch:0,at:Double(frame)*8/60))
        for (a,b) in zip(baseFeet,sample) { footVertexDrift=max(footVertexDrift,length(a-b)) }
    }
    guard footVertexDrift<0.00001 else { throw failure("Idle moved the skinned foot surface") }
    var timings:[Double]=[]
    renderer.fanMorphIndices=[0,1]
    for i in 0..<360 {
        renderer.fanMorphWeights=[0.3,0.35+0.3*sin(Float(i)*0.08)]
        let (_,ms)=try renderer.offscreen(width:800,height:640,at:Double(i)/120)
        if i>=60 { timings.append(ms) }
    }
    timings.sort()
    let report:[String:Any]=["device":device.name,"sourcePoseMatrixError":bindError,"idleLegTransformError":footTransformError,"idleFootVertexDrift":footVertexDrift,"footVertexSamples":footVertices.count,"minimumFootY":baseFeet.map(\.y).min()!,"gpuP50MS":timings[timings.count/2],"gpuP95MS":timings[Int(Double(timings.count)*0.95)],"gpuMaxMS":timings.last!,"samples":timings.count,"msaaSamples":renderer.sampleCount,"note":"Eight-influence skinned fan mesh with two animated facial morphs, 800x640, soft shadows. Offscreen GPU timing; display pacing remains unverified. Includes weighted foot-surface samples over eight seconds of idle."]
    try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:"\(folder)/checks.json"))
    print(report)
    print("Skinned fan geometry rendered with existing Metal lighting, MSAA and soft shadows: \(folder)")
}
