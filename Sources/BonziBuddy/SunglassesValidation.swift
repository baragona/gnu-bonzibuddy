import Foundation
import simd

func validateSunglasses() throws {
    func error(_ a:simd_float4x4,_ b:simd_float4x4)->Float {
        (0..<4).reduce(Float(0)) {m,c in (0..<4).reduce(m) {max($0,abs(a[c][$1]-b[c][$1]))}}
    }
    let rig=try FanRig(url:URL(fileURLWithPath:"Resources/FanModel/FanRig.json")),motion=PropMotion()
    var player=ActionPlayback()
    player.play(.sunglasses,at:0,mode:.hold)
    func evaluate(_ time:Double)->([PropDraw],[Instance]) {
        let state=player.sample(at:time)
        rig.updateLiveAction(state.action,started:state.started,at:time,elapsed:state.elapsed)
        let bones=rig.instances(yaw:-0.6,pitch:0.18,at:time)
        return (motion.sample(action:state.action,started:state.started,at:time,cues:rig.routine.props,rig:rig,bones:bones),bones)
    }
    var handError:Float=0,headError:Float=0
    for frame in 0...Int(12.6*120) {
        let t=Double(frame)/120,(draws,bones)=evaluate(t)
        for draw in draws {
            if t>=0.9 && t<=1.3 {
                let grip=draw.model*SIMD4(SunglassesRoutine.grip,1)
                let wrist=rig.attachmentFrame(.wrist(.left),axes:.character,bones:bones).columns.3
                handError=max(handError,length(grip-wrist))
            }
            if t>=2 && t<=10.3 {
                headError=max(headError,error(draw.model,rig.attachmentFrame(.head,axes:.joint,bones:bones)))
            }
        }
    }
    let seamBefore=evaluate(12.6-0.00001).0,seamAfter=evaluate(12.6+0.00001).0
    guard seamBefore.count==1,seamAfter.count==1 else {throw failure("Glasses disappeared at hold loop seam")}
    let seamError=error(seamBefore[0].model,seamAfter[0].model)
    let late=player.sample(at:100)
    guard late.action == .sunglasses,SunglassesRoutine.holdRange.contains(late.elapsed) else {throw failure("Held routine expired")}
    // Finish while the head is turned; the return must capture that displayed pose.
    let before=evaluate(16.5).0
    guard player.finish(at:16.5) else {throw failure("Held routine rejected its return")}
    let after=evaluate(16.5).0
    guard before.count==1,after.count==1 else {throw failure("Glasses disappeared at return start")}
    let returnJump=error(before[0].model,after[0].model)
    var last:[PropDraw]=[]
    for frame in 1...242 {last=evaluate(16.5+Double(frame)/120).0}
    guard player.sample(at:18.51).action == .idle,last.isEmpty else {throw failure("Glasses survived their removal")}
    guard player.sample(at:16.0).action == .sunglasses else {throw failure("Seeking before a return lost the held clip")}
    var early=ActionPlayback();early.play(.sunglasses,at:0,mode:.hold)
    guard early.finish(at:0.5),early.sample(at:1).elapsed==1,early.sample(at:1.9).elapsed==12.6 else {throw failure("Early return skipped the entrance")}
    _=early.finish(at:2.0)
    guard abs(early.sample(at:2.1).elapsed-12.8)<0.00001 else {throw failure("Repeated finish restarted the return")}
    let asset=try PropAssetData(url:PropAssetData.url("FanSunglasses.mesh"))
    guard handError<0.00001,headError<0.00001,seamError<0.0001,returnJump<0.0001 else {throw failure("Sunglasses attachment continuity failed")}
    let report:[String:Any]=["maximumHandGripError":handError,"maximumHeadAttachmentError":headError,"loopSeamMatrixError":seamError,"returnStartMatrixJump":returnJump,"heldAt100Seconds":true,"earlyAndRepeatedReturnPassed":true,"returnRetiredProps":last.isEmpty,"assetVertices":asset.vertices.count/80,"assetTriangles":asset.indexCount/3,"note":"Playback/attachment contracts, not proof of anatomical fit, finger contact, or original visual fidelity."]
    try FileManager.default.createDirectory(atPath:"Validation/Sunglasses",withIntermediateDirectories:true)
    let data=try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]);try data.write(to:URL(fileURLWithPath:"Validation/Sunglasses/checks.json"));print(String(decoding:data,as:UTF8.self))
}
