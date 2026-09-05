import AppKit
import MetalKit
import simd

func validateFanTransitions() throws {
    let url=URL(fileURLWithPath:"Resources/FanModel/FanRig.json")
    var jump:Float=0,settled:Float=0,footDrift:Float=0
    func error(_ a:[Instance],_ b:[Instance],_ ids:[Int]?=nil)->Float {
        var result:Float=0
        for i in ids ?? Array(a.indices) { for c in 0..<4 { for r in 0..<4 { result=max(result,abs(a[i].model[c][r]-b[i].model[c][r])) } } }
        return result
    }
    for from in Action.allCases { for to in Action.allCases {
        let rig=try FanRig(url:url)
        rig.updateLiveAction(from,started:0,at:0)
        _=rig.instances(yaw:0,pitch:0,at:0)
        rig.updateLiveAction(from,started:0,at:0.8)
        let before=rig.instances(yaw:0,pitch:0,at:0.8)
        rig.updateLiveAction(to,started:0.8,at:0.8)
        let after=rig.instances(yaw:0,pitch:0,at:0.8)
        jump=max(jump,error(before,after))
        for frame in 1...30 {
            let time=0.8+Double(frame)/120
            rig.updateLiveAction(to,started:0.8,at:time)
            let pose=rig.instances(yaw:0,pitch:0,at:time)
            footDrift=max(footDrift,error(before,pose,Array(12...19)))
            guard pose.allSatisfy({ m in (0..<4).allSatisfy { c in (0..<4).allSatisfy { m.model[c][$0].isFinite } } }) else { throw failure("Non-finite interrupted pose") }
        }
        let target=try FanRig(url:url)
        target.action=to;target.actionTime=0.25;target.waveTime=to == .wave ? 0.25:nil
        settled=max(settled,error(rig.instances(yaw:0,pitch:0,at:1.05),target.instances(yaw:0,pitch:0,at:1.05)))
        // A second interruption while the first blend is active must start from the displayed pose.
        rig.updateLiveAction(from,started:1.05,at:1.05)
        _=rig.instances(yaw:0,pitch:0,at:1.05)
        rig.updateLiveAction(from,started:1.05,at:1.10)
        let middle=rig.instances(yaw:0,pitch:0,at:1.10)
        rig.updateLiveAction(to,started:1.10,at:1.10)
        jump=max(jump,error(middle,rig.instances(yaw:0,pitch:0,at:1.10)))
    } }
    guard jump<0.0001,settled<0.0001,footDrift<0.0001 else { throw failure("Fan transition continuity failed: jump \(jump), settled \(settled), feet \(footDrift)") }
    var faceJump:Float=0,faceSettled:Float=0
    for from in Action.allCases { for to in Action.allCases { for interrupt in [0.12,0.5,0.8] {
        let face=FanFaceMotion()
        _=face.sample(from,started:0,at:0)
        let before=face.sample(from,started:0,at:interrupt)
        let after=face.sample(to,started:interrupt,at:interrupt)
        faceJump=max(faceJump,length(before-after))
        let finished=face.sample(to,started:interrupt,at:interrupt+0.2)
        faceSettled=max(faceSettled,length(finished-FanFaceMotion.target(to,elapsed:0.2)))
        _=face.sample(from,started:interrupt+0.2,at:interrupt+0.2)
        let middle=face.sample(from,started:interrupt+0.2,at:interrupt+0.25)
        faceJump=max(faceJump,length(middle-face.sample(to,started:interrupt+0.25,at:interrupt+0.25)))
    } } }
    guard faceJump<0.000001,faceSettled<0.000001 else { throw failure("Automatic facial transition continuity failed") }
    let folder="Validation/FanTransitions"
    try FileManager.default.createDirectory(atPath:folder,withIntermediateDirectories:true)
    let report:[String:Any]=["actionPairs":Action.allCases.count*Action.allCases.count,"maximumStartMatrixJump":jump,"maximumSettledMatrixError":settled,"maximumLegMatrixDrift":footDrift,"blendSeconds":0.20,"facialCases":300,"maximumFacialStartJump":faceJump,"maximumFacialSettledError":faceSettled,"note":"All ordered action pairs plus re-interruption during an active blend. Checks skeletal continuity, convergence and stationary leg transforms; not original choreography or collision-free motion."]
    let data=try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]);try data.write(to:URL(fileURLWithPath:"\(folder)/checks.json"));print(String(decoding:data,as:UTF8.self))
    guard let device=MTLCreateSystemDefaultDevice() else { throw failure("Metal GPU unavailable") }
    let renderer=try Renderer(device:device,previewMesh:URL(fileURLWithPath:"Resources/FanModel/FanRigged.mesh"),rigURL:url)
    renderer.fanLiveActions=true;renderer.fanTeethEnabled=true
    renderer.character.play(.wave,at:0)
    for frame in 0...45 {
        let time=Double(frame)/30
        if frame==24 { renderer.character.play(.dance,at:time) }
        if frame==27 { renderer.character.play(.shrug,at:time) }
        for (angle,yaw) in [("front",Float(0)),("quarter",-Float.pi/4)] {
            renderer.character.yaw=yaw
            let (texture,_)=try renderer.offscreen(width:800,height:640,at:time)
            if [23,24,25,27,28,30,33,40,45].contains(frame) { try writePNG(texture,to:"\(folder)/\(angle)-\(frame).png") }
        }
    }
    renderer.character.yaw=0
    renderer.character.play(.speak,at:2)
    for frame in 0...30 {
        let time=2+Double(frame)/60
        if frame==12 { renderer.character.play(.idle,at:time) }
        let (texture,_)=try renderer.offscreen(width:800,height:640,at:time)
        if [0,6,11,12,15,18,24,30].contains(frame) { try writePNG(texture,to:"\(folder)/speech-stop-\(frame).png") }
    }

}
