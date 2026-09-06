import MetalKit
import simd

func validateVine() throws {
    guard let device=MTLCreateSystemDefaultDevice() else {throw failure("Metal unavailable")}
    let renderer=try Renderer(device:device,previewMesh:URL(fileURLWithPath:"Resources/FanModel/FanRigged.mesh"),rigURL:URL(fileURLWithPath:"Resources/FanModel/FanRig.json"))
    renderer.fanLiveActions=true;renderer.drawCharacterGeometry=false
    let (vertices,indices)=VineGeometry.mesh()
    guard !vertices.isEmpty,indices.count%3==0,indices.allSatisfy({Int($0)<vertices.count}),vertices.allSatisfy({v in
        (0..<4).allSatisfy({v.position[$0].isFinite && v.normal[$0].isFinite && v.uv[$0].isFinite}) && abs(length(v.normal)-1)<0.001
    }) else {throw failure("Invalid vine topology or normals")}
    var bend:Float=0,frame:AuditFrame?
    renderer.fanRig!.auditPoseAdjustment={pose in
        pose.props=[PropCue(id:"vine-study",kind:.vine,anchor:.character,offset:[0.5,-0.85,0],scale:SIMD3(repeating:0.72),deformation:.vine(bend:bend))]
    }
    renderer.onAuditFrame={frame=AuditFrame(bones:$0,props:$1,morphs:$2)}
    let gpu=try AuditGPU(renderer)
    var maximumError:Float=0,maximumAnchorDrift:Float=0
    let values=(0...120).map {Float($0)/24-2.5}+[Float(-0.00001),0,0.00001]
    for value in values {
        bend=value
        _=try renderer.offscreen(width:160,height:128,at:0)
        let captured=frame!,points=try gpu.positions(captured).1["vine-study"]!,inverse=captured.props[0].model.inverse
        for i in vertices.indices {
            let t=Double(vertices[i].uv.z),a=Double(value)*t,l=Double(VineGeometry.length)
            func sinc(_ x:Double)->Double {abs(x)<1e-8 ? 1:sin(x)/x}
            let center=SIMD3<Float>(Float(-l*t*sin(a/2)*sinc(a/2)),Float(l*t*sinc(a)),0)
            let local=vertices[i].position-SIMD4<Float>(0,Float(t)*VineGeometry.length,0,0)
            let expected=center+simd_quatf(angle:Float(a),axis:[0,0,1]).act(SIMD3(local.x,local.y,local.z))
            let p=inverse*SIMD4(points[i],1),actual=SIMD3(p.x,p.y,p.z)
            maximumError=max(maximumError,length(actual-expected))
            if vertices[i].uv.z==0 {maximumAnchorDrift=max(maximumAnchorDrift,length(actual-SIMD3(vertices[i].position.x,vertices[i].position.y,vertices[i].position.z)))}
        }
    }
    guard maximumError<0.00001,maximumAnchorDrift<0.00001 else {throw failure("Vine deformation detached from its grip or leaf frames")}
    try FileManager.default.createDirectory(atPath:"Validation/Vine",withIntermediateDirectories:true)
    for value:Float in [0,0.7,-0.7,2.3] {
        bend=value
        for (name,yaw) in [("front",Float(0)),("quarter",-Float.pi/4),("left",-Float.pi/2),("right",Float.pi/2)] {
            renderer.character.yaw=yaw
            let (texture,_)=try renderer.offscreen(width:800,height:640,at:0)
            try writePNG(texture,to:"Validation/Vine/vine-\(value)-\(name).png")
        }
    }
    let report:[String:Any]=["vertices":vertices.count,"triangles":indices.count/3,"bendSamples":values.count,"renderedViews":16,"maximumGPUPositionError":maximumError,"maximumGripAnchorDrift":maximumAnchorDrift,"msaaSamples":renderer.sampleCount,"note":"GPU positions versus an independent double-precision circular-arc reference, including zero bend, both directions, and attached leaves. Shared color/shadow/audit deformation. This validates the asset; entrance/exit choreography, grip fitting, dust, and presence lifecycle remain unimplemented."]
    let data=try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys])
    try data.write(to:URL(fileURLWithPath:"Validation/Vine/checks.json"));print(String(decoding:data,as:UTF8.self))
}
