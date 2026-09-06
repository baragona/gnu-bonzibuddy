import MetalKit
import simd

func validateWinkBrow() throws {
    guard let device=MTLCreateSystemDefaultDevice() else {throw failure("Metal unavailable")}
    let renderer=try Renderer(device:device,previewMesh:URL(fileURLWithPath:"Resources/FanModel/FanRigged.mesh"),rigURL:URL(fileURLWithPath:"Resources/FanModel/FanRig.json"))
    renderer.fanLiveActions=true;renderer.character.play(.wink,at:0)
    let gpu=try AuditGPU(renderer)
    var frame:AuditFrame?
    renderer.onAuditFrame={frame=AuditFrame(bones:$0,props:$1,morphs:$2)}
    _=try renderer.offscreen(width:160,height:128,at:0)
    _=try renderer.offscreen(width:160,height:128,at:0.8)
    let automatic=frame!,posed=try gpu.positions(automatic).0
    renderer.fanExpressionOverrides[4]=0
    _=try renderer.offscreen(width:160,height:128,at:0.8)
    let overridden=frame!,neutral=try gpu.positions(overridden).0
    var lowered:Float=0,opposite:Float=0,changed=0
    for i in posed.indices {
        let x=renderer.vertices.contents().load(fromByteOffset:i*128,as:Float.self)
        let delta=posed[i]-neutral[i]
        if x>0.05 {lowered=max(lowered,-delta.y);if length(delta)>1e-6 {changed+=1}}
        if x < -0.05 {opposite=max(opposite,length(delta))}
    }
    guard automatic.morphs.browLower.x>0.39,automatic.morphs.browLower.y==0,
          overridden.morphs.browLower == .zero,lowered>0.001,lowered<0.03,opposite<1e-6,changed>20 else {throw failure("Wink brow isolation or manual override failed")}
    let report:[String:Any]=["changedLeftVertices":changed,"maximumLeftLowering":lowered,"maximumOppositeDisplacement":opposite,"manualOverridePassed":true,"note":"Actual GPU-deformed mesh at the identical head pose, automatic left brow versus a manual zero override. Excludes the smoothly blended center strip from the opposite-side bound."]
    try FileManager.default.createDirectory(atPath:"Validation/WinkBrow",withIntermediateDirectories:true)
    let data=try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys])
    try data.write(to:URL(fileURLWithPath:"Validation/WinkBrow/checks.json"))
    print(String(decoding:data,as:UTF8.self))
}
