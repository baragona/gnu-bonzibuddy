import Foundation
import simd

func validateWinkMotion() throws {
    let rig=try FanRig(url:URL(fileURLWithPath:"Resources/FanModel/FanRig.json"))
    var angles:[Float]=[]
    for frame in 0...216 {
        let t=Double(frame)/120
        rig.updateLiveAction(.wink,started:0,at:t)
        let bones=rig.instances(yaw:0,pitch:0,at:t)
        let forward=bones[56].model*rig.rest[56].columns.2
        angles.append(atan2(forward.x,forward.z))
    }
    let hold=Array(angles[72...156])
    let drift=hold.max()!-hold.min()!
    // Check the displayed head's speed, not just its authored scalar track.
    // Each travel phase must accelerate once and decelerate once: extra eased
    // keys or eyelid-driven movement produced the reported stop/start motion.
    var maximumSpeedIncreaseAfterPeak:Float=0,maximumSpeedDropBeforePeak:Float=0
    for (start,end,direction) in [(12,72,Float(-1)),(156,204,Float(1))] {
        let speeds=(start..<end).map {(angles[$0+1]-angles[$0])*120*direction}
        guard speeds.min()! >= -0.001 else {throw failure("Wink head reverses during a turn")}
        let peak=speeds.indices.max(by:{speeds[$0]<speeds[$1]})!
        for i in 1..<speeds.count {
            if i<=peak {maximumSpeedDropBeforePeak=max(maximumSpeedDropBeforePeak,speeds[i-1]-speeds[i])}
            else {maximumSpeedIncreaseAfterPeak=max(maximumSpeedIncreaseAfterPeak,speeds[i]-speeds[i-1])}
        }
    }
    let eyeChange=abs(WinkRoutine.sample(at:0.8).face.individualEyeClosure.x-WinkRoutine.sample(at:1.1).face.individualEyeClosure.x)
    let report:[String:Any]=["samples":angles.count,"maximumHeldHeadYawDrift":drift,"maximumSpeedDropBeforePeak":maximumSpeedDropBeforePeak,"maximumSpeedIncreaseAfterPeak":maximumSpeedIncreaseAfterPeak,"eyelidChangeDuringHeadHold":eyeChange,"headYawRadians":angles,"note":"Actual rig head direction at 120 Hz: one acceleration/deceleration per turn, stationary head while eyelid reopens. Not a live presentation pacing measurement."]
    try FileManager.default.createDirectory(atPath:"Validation/WinkMotion",withIntermediateDirectories:true)
    let data=try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys])
    try data.write(to:URL(fileURLWithPath:"Validation/WinkMotion/checks.json"))
    guard drift<0.00001,maximumSpeedDropBeforePeak<0.005,maximumSpeedIncreaseAfterPeak<0.005,eyeChange>0.99 else {throw failure("Wink head has a secondary stop/start or follows the eyelid")}
    print("Wink head motion passed: \(angles.count) samples, hold drift \(drift)")
}
