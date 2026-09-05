import Foundation
import simd

func validateProps() throws {
    let rig=try FanRig(url:URL(fileURLWithPath:"Resources/FanModel/FanRig.json"))
    let motion=PropMotion()
    var maxAnchorError:Float=0
    var last:[PropDraw]=[]
    for frame in 0...744 {
        let t=Double(frame)/120
        rig.updateLiveAction(.globe,started:0,at:t)
        let bones=rig.instances(yaw:-0.7,pitch:0.1,at:t)
        let draws=motion.sample(action:.globe,started:0,at:t,cues:rig.routine.props,rig:rig,bones:bones,yaw:-0.7,pitch:0.1)
        for draw in draws {
            guard (0..<4).allSatisfy({ c in (0..<4).allSatisfy({draw.model[c][$0].isFinite}) }) else {throw failure("Nonfinite prop")}
        }
        if let cue=rig.routine.props.first,let draw=draws.first {
            let expected=bones[26].model*rig.rest[26].columns.3+bones[0].model*SIMD4(cue.offset,0)
            maxAnchorError=max(maxAnchorError,length(expected-draw.model.columns.3))
        }
        if frame==240 {last=draws}
    }
    guard maxAnchorError<0.00001 else {throw failure("Prop detached from solved wrist")}
    guard RoutineLibrary.sample(.globe,at:0).props.isEmpty && RoutineLibrary.sample(.globe,at:6.2).props.isEmpty else {throw failure("Prop leaked beyond routine")}
    // Sample an interruption at full visibility, including a second interruption.
    let interrupted=PropMotion()
    rig.updateLiveAction(.globe,started:0,at:2)
    let bones=rig.instances(yaw:0,pitch:0,at:2)
    let before=interrupted.sample(action:.globe,started:0,at:2,cues:rig.routine.props,rig:rig,bones:bones,yaw:0,pitch:0)
    let first=interrupted.sample(action:.wave,started:2,at:2,cues:[],rig:rig,bones:bones,yaw:0,pitch:0)
    guard before.count==1,first.count==1,length(before[0].model.columns.3-first[0].model.columns.3)<0.00001 else {throw failure("Prop disappeared at interruption")}
    _=interrupted.sample(action:.wave,started:2,at:2.08,cues:[],rig:rig,bones:bones,yaw:0,pitch:0)
    _=interrupted.sample(action:.idle,started:2.08,at:2.08,cues:[],rig:rig,bones:bones,yaw:0,pitch:0)
    let after=interrupted.sample(action:.idle,started:2.08,at:2.4,cues:[],rig:rig,bones:bones,yaw:0,pitch:0)
    guard after.isEmpty,!last.isEmpty else {throw failure("Interrupted prop was not retired")}
    let report:[String:Any]=["sampledFrames":745,"maximumWristAnchorError":maxAnchorError,"interruptionRetirementPassed":true,"note":"Numerical attachment and lifecycle checks; visual match is reviewed separately."]
    try FileManager.default.createDirectory(atPath:"Validation/Props",withIntermediateDirectories:true)
    let data=try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]);try data.write(to:URL(fileURLWithPath:"Validation/Props/checks.json"));print(String(decoding:data,as:UTF8.self))
}
