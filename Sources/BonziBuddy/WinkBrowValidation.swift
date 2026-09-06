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
    try FileManager.default.createDirectory(atPath:"Validation/WinkBrow",withIntermediateDirectories:true)
    renderer.fanExpressionOverrides.removeValue(forKey:4)
    renderer.character.play(.idle,at:0)
    _=try renderer.offscreen(width:160,height:128,at:0)
    var blinkSamples=[[String:Any]]()
    for (name,time) in [("open",3.9),("half",4.04),("closed",4.10),("reopening",4.20),("restored",4.3)] {
        for (view,yaw) in [("front",Float(0)),("quarter",-Float.pi/4),("left",-Float.pi/2)] {
            renderer.character.yaw=yaw
            let (texture,_)=try renderer.offscreen(width:800,height:640,at:time)
            let captured=frame!
            let expected=0.18*(1-BlinkAnimation.eyeOpen(at:time))
            guard abs(captured.morphs.browLower.x-expected)<1e-6,
                  abs(captured.morphs.browLower.y-expected)<1e-6 else {throw failure("Natural blink brow synchronization failed")}
            try writePNG(texture,to:"Validation/WinkBrow/blink-\(name)-\(view).png")
            if view == "front" {blinkSamples.append(["phase":name,"time":time,"browLower":expected])}
        }
    }
    renderer.fanAutoBlink=false
    renderer.fanIndividualEyeClosure=[0,1]
    _=try renderer.offscreen(width:160,height:128,at:4.1)
    guard frame!.morphs.browLower.x==0,abs(frame!.morphs.browLower.y-0.18)<1e-6 else {throw failure("Right blink brow isolation failed")}
    renderer.fanExpressionOverrides[4]=0
    _=try renderer.offscreen(width:160,height:128,at:4.1)
    guard frame!.morphs.browLower == .zero else {throw failure("Blink brow manual override failed")}
    let report:[String:Any]=["changedLeftVertices":changed,"maximumLeftLowering":lowered,"maximumOppositeDisplacement":opposite,"manualOverridePassed":true,"naturalBlinkSamples":blinkSamples,"rightBlinkIsolationPassed":true,"note":"Actual GPU-deformed wink mesh at the identical head pose, automatic left brow versus a manual zero override. Also checks natural blink synchronization, return to neutral, and independent right-eye control; renders three angles."]
    let data=try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys])
    try data.write(to:URL(fileURLWithPath:"Validation/WinkBrow/checks.json"))
    print(String(decoding:data,as:UTF8.self))
}
