import Foundation
import MetalKit
import simd

func validateWearables() throws {
    func require(_ condition:Bool,_ message:String) throws {if !condition {throw failure(message)}}
    var toggle=WearablePlayback(definition:.sunglasses)
    toggle.setEnabled(true,at:0)
    toggle.setEnabled(false,at:0.5)
    try require(!toggle.requested && toggle.transfer(at:1)?.enabled==true,"Early off interrupted pickup")
    try require(toggle.transfer(at:2)?.enabled==false && !toggle.worn(at:4),"Early off failed to remove")
    toggle.setEnabled(true,at:0.8)
    try require(toggle.busyUntil==1.9 && toggle.worn(at:2),"Cancel pending removal failed")
    toggle.setEnabled(false,at:3)
    toggle.setEnabled(true,at:3.5)
    try require(toggle.transfer(at:4)?.enabled==false && toggle.transfer(at:5)?.enabled==true && toggle.worn(at:7),"Reverse removal failed")
    let end=toggle.busyUntil;toggle.setEnabled(true,at:3.6)
    try require(toggle.busyUntil==end,"Idempotent set restarted transfer")
    let character=Character()
    character.setSunglassesEnabled(true,at:0)
    character.play(.wave,at:0.5)
    try require(character.playbackSnapshot(at:1).action == .sunglasses,"Action interrupted accessory transfer")
    try require(character.playbackSnapshot(at:2).action == .wave && character.wearsSunglasses(at:2),"Queued action lost glasses")
    let occupied=Character()
    occupied.setSunglassesEnabled(true,at:0)
    occupied.play(.juggle,at:3)
    occupied.setSunglassesEnabled(false,at:4)
    try require(occupied.playbackSnapshot(at:5).action == .juggle && occupied.wearsSunglasses(at:5),"Transfer stole juggling hands")
    occupied.play(.wave,at:5)
    try require(occupied.playbackSnapshot(at:6).action == .juggle,"Queued action cut off prop stow")
    try require(occupied.playbackSnapshot(at:10).action == .sunglasses,"Deferred removal did not start")
    try require(occupied.playbackSnapshot(at:12).action == .wave && !occupied.wearsSunglasses(at:12),"Deferred removal lost queued action")
    let cancelled=Character();cancelled.setSunglassesEnabled(true,at:0);cancelled.play(.juggle,at:3)
    cancelled.setSunglassesEnabled(false,at:4);cancelled.setSunglassesEnabled(true,at:5)
    try require(cancelled.playbackSnapshot(at:6).action == .juggle && cancelled.wearsSunglasses(at:10),"Cancel deferred removal interrupted routine")
    let rig=try FanRig(url:URL(fileURLWithPath:"Resources/FanModel/FanRig.json")),motion=PropMotion()
    var maximumAttachmentError:Float=0,samples=0
    for action in Action.allCases where action != .sunglasses {
        character.play(action,at:10)
        for frame in 0...120 {
            let time=10+Double(frame)/120*min(action.duration-0.001,4)
            let state=character.playbackSnapshot(at:time)
            try require(state.action == action && character.wearsSunglasses(at:time),"Accessory displaced body action: \(action.rawValue) at \(time)")
            rig.updateLiveAction(state.action,started:state.started,at:time,elapsed:state.elapsed)
            let bones=rig.instances(yaw:-0.6,pitch:0.18,at:time)
            let cues=rig.routine.props+[PropCue(id:"sunglasses",kind:.sunglasses,anchor:.attachment(.head,axes:.joint),offset:.zero)]
            let draws=motion.sample(action:state.action,started:state.started,at:time,cues:cues,rig:rig,bones:bones)
            let glasses=draws.filter {$0.id=="sunglasses"}
            try require(glasses.count==1,"Duplicate or missing wearable")
            let expected=rig.attachmentFrame(.head,axes:.joint,bones:bones)
            for c in 0..<4 {for r in 0..<4 {maximumAttachmentError=max(maximumAttachmentError,abs(glasses[0].model[c][r]-expected[c][r]))}}
            samples+=1
        }
    }
    try require(maximumAttachmentError<0.00001,"Wearable drifted off head")
    character.play(.idle,at:20)
    character.setSunglassesEnabled(false,at:20)
    try require(character.playbackSnapshot(at:20.1).action == .sunglasses && !character.wearsSunglasses(at:22),"Toggle off failed")
    guard let device=MTLCreateSystemDefaultDevice() else {throw failure("Metal unavailable")}
    let renderer=try Renderer(device:device,previewMesh:URL(fileURLWithPath:"Resources/FanModel/FanRigged.mesh"),rigURL:URL(fileURLWithPath:"Resources/FanModel/FanRig.json"))
    renderer.fanLiveActions=true;renderer.fanTeethEnabled=true
    renderer.character.setSunglassesEnabled(true,at:0)
    let folder="Validation/Wearables"
    try FileManager.default.createDirectory(atPath:folder,withIntermediateDirectories:true)
    for action in [Action.wave,.dance,.speak,.globe,.juggle,.banana,.surprised] {
        renderer.character.play(action,at:10)
        for (camera,yaw) in [Float(0),-Float.pi/4,-Float.pi/2].enumerated() {
            renderer.character.yaw=yaw
            _=try renderer.offscreen(width:400,height:320,at:10)
            let (texture,_)=try renderer.offscreen(width:400,height:320,at:12)
            try writePNG(texture,to:"\(folder)/\(action.rawValue)-\(camera).png")
        }
    }
    renderer.character.play(.dance,at:20)
    renderer.character.setSunglassesEnabled(false,at:21)
    for (index,time) in [21.0,21.2,21.5,21.8,22.1,22.5,22.9,23.2].enumerated() {
        for (camera,yaw) in [Float(0),-Float.pi/4,-Float.pi/2].enumerated() {
            renderer.character.yaw=yaw
            let (texture,_)=try renderer.offscreen(width:400,height:320,at:time)
            try writePNG(texture,to:"\(folder)/removal-\(index)-\(camera).png")
        }
    }
    let resumed=renderer.character.playbackSnapshot(at:23)
    try require(resumed.action == .dance && abs(resumed.elapsed-1.1)<0.00001,"Transfer failed to resume action time")
    let report:[String:Any]=["samples":samples,"maximumHeadAttachmentError":maximumAttachmentError,"rapidToggleAndIdempotencePassed":true,"actionDuringTransferPassed":true,"renderedCombinationViews":21]
    let data=try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys])
    try data.write(to:URL(fileURLWithPath:"\(folder)/checks.json"));print(String(decoding:data,as:UTF8.self))
}
