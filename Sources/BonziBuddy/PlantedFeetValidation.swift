import Foundation
import simd

// For standing routines that move the pelvis but do not author foot targets.
func validatePlantedFeet() throws {
    let args=CommandLine.arguments
    guard let i=args.firstIndex(of:"--action"),i+1<args.count,
          let action=Action.allCases.first(where:{$0.rawValue.lowercased()==args[i+1].lowercased()}),
          action.duration.isFinite,!action.changesFacing else {throw failure("Select one finite, non-turning action with --action")}
    let rig=try FanRig(url:URL(fileURLWithPath:"Resources/FanModel/FanRig.json"))
    var first:[Instance]=[],drift:Float=0,pelvisTravel:Float=0
    let count=Int(ceil(action.duration*120))+1
    for frame in 0..<count {
        let time=Double(frame)/120
        guard RoutineLibrary.sample(action,at:time).stance.feet.isEmpty else {throw failure("Routine authors foot movement; fixed-foot validation does not apply")}
        rig.updateLiveAction(action,started:0,at:time)
        let bones=rig.instances(yaw:0,pitch:0,at:time)
        if first.isEmpty {first=bones}
        for joint in [14,15,18,19] {for column in 0..<4 {drift=max(drift,length(bones[joint].model[column]-first[joint].model[column]))}}
        let rest=rig.rest[20].columns.3
        pelvisTravel=max(pelvisTravel,length(bones[20].model*rest-first[20].model*rest))
    }
    guard drift<1e-5 else {throw failure("Planted feet drift during \(action.rawValue): \(drift)")}
    let report:[String:Any]=["action":action.rawValue,"samples":count,"maximumFootMatrixDrift":drift,"maximumPelvisTravel":pelvisTravel,"note":"Actual ankle/toe matrices across a standing routine at 120 Hz. This does not establish collision avoidance or live frame pacing."]
    let folder="Validation/PlantedFeet"
    try FileManager.default.createDirectory(atPath:folder,withIntermediateDirectories:true)
    let data=try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys])
    try data.write(to:URL(fileURLWithPath:"\(folder)/\(action.rawValue.lowercased().replacingOccurrences(of:" ",with:"-")).json"))
    print(String(decoding:data,as:UTF8.self))
}
