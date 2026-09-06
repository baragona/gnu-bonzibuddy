import MetalKit
import simd

func validateVineEntrance() throws {
    guard let device=MTLCreateSystemDefaultDevice() else {throw failure("Metal unavailable")}
    let renderer=try Renderer(device:device,previewMesh:URL(fileURLWithPath:"Resources/FanModel/FanRigged.mesh"),rigURL:URL(fileURLWithPath:"Resources/FanModel/FanRig.json"))
    renderer.fanLiveActions=true;renderer.fanTeethEnabled=true
    renderer.character.play(.vineEntrance,at:0)
    var frame:AuditFrame?,maximumGripError:Float=0,gripSamples=0
    renderer.onAuditFrame={frame=AuditFrame(bones:$0,props:$1,morphs:$2)}
    let rig=renderer.fanRig!,folder="Validation/VineEntrance"
    try FileManager.default.createDirectory(atPath:folder,withIntermediateDirectories:true)
    for i in 0...324 {
        let t=Double(i)/120
        _=try renderer.offscreen(width:160,height:128,at:t)
        guard let frame else {throw failure("Missing entrance frame")}
        if t>=1.55 && t<=1.95 {
            for side in HandSide.allCases {
                let hand=rig.routine.hands[side]!,offset=rig.handAnatomy(side).surfaceOffset(fingers:hand.fingers,palm:hand.palm)
                let contact=rig.attachmentFrame(.wrist(side),axes:.character,bones:frame.bones).columns.3+frame.bones[0].model*SIMD4(offset,0)
                let expected=frame.bones[0].model*SIMD4(hand.palmContact!,1)
                maximumGripError=max(maximumGripError,length(contact-expected));gripSamples+=1
            }
        }
    }
    // Diagnostic isolation: determine whether any visible pale fragments belong
    // to the separate tooth mesh or the body/hand skin before editing materials.
    for teeth in [false,true] {
        renderer.fanTeethEnabled=teeth
        let (texture,_)=try renderer.offscreen(width:800,height:640,at:1.8)
        try writePNG(texture,to:"\(folder)/swing-teeth-\(teeth).png")
    }
    let report:[String:Any]=["duration":VineEntranceRoutine.duration,"frames":325,"gripSamples":gripSamples,"maximumPalmTargetError":maximumGripError,"note":"Actual rig palm-frame markers versus authored contact targets during the two-hand hold. Surface intersections and original fidelity are evaluated separately; contact error is reported, not treated as proof of a fitted grip."]
    let data=try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys])
    try data.write(to:URL(fileURLWithPath:"\(folder)/checks.json"));print(String(decoding:data,as:UTF8.self))
}
