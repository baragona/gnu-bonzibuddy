import Foundation
import simd

func validateMail() throws {
    var vertices=0,triangles=0
    for kind in [PropKind.mailbox,.mailboxDoor,.letterBack,.letterFlap] {
        let mesh=(kind == .letterBack || kind == .letterFlap) ? LetterGeometry.mesh(kind):MailboxGeometry.mesh(kind)
        for v in mesh.0 {
            guard (0..<4).allSatisfy({v.position[$0].isFinite && v.normal[$0].isFinite}),abs(length(SIMD3(v.normal.x,v.normal.y,v.normal.z))-1)<0.001 else {throw failure("Invalid mailbox vertex/normal")}
        }
        for i in stride(from:0,to:mesh.1.count,by:3) {
            let v=(0..<3).map {mesh.0[Int(mesh.1[i+$0])]}
            let p=v.map {SIMD3<Float>($0.position.x,$0.position.y,$0.position.z)}
            let n=cross(p[1]-p[0],p[2]-p[0]),normal=v.reduce(SIMD4<Float>.zero) {$0+$1.normal}
            guard length(n)>1e-12,dot(n,SIMD3(normal.x,normal.y,normal.z))>0 else {throw failure("Invalid mailbox winding")}
        }
        vertices+=mesh.0.count;triangles+=mesh.1.count/3
    }
    let rig=try FanRig(url:URL(fileURLWithPath:"Resources/FanModel/FanRig.json")),motion=PropMotion()
    var groundError:Float=0,hingeError:Float=0,ankleDrift:Float=0
    var planted:[SIMD4<Float>]=[]
    for frame in 0...420 {
        let t=Double(frame)/120
        rig.updateLiveAction(.mailEmpty,started:0,at:t,elapsed:t)
        let bones=rig.instances(yaw:0,pitch:0,at:t)
        let ankles=[14,18].map {bones[$0].model*rig.rest[$0].columns.3}
        if planted.isEmpty {planted=ankles}
        for i in 0..<2 {ankleDrift=max(ankleDrift,length(ankles[i]-planted[i]))}
        let draws=motion.sample(action:.mailEmpty,started:0,at:t,cues:MailEmptyRoutine.sample(at:t).props,rig:rig,bones:bones)
        if let box=draws.first(where:{$0.kind == .mailbox}),let door=draws.first(where:{$0.kind == .mailboxDoor}) {
            let bottom=box.model*SIMD4<Float>(0,-1,0,1)
            groundError=max(groundError,abs(bottom.y+0.92))
            let expected=box.model*SIMD4<Float>(0.265,-0.155,0,1)
            hingeError=max(hingeError,length(expected-door.model.columns.3))
        }
    }
    guard groundError<0.00001,hingeError<0.00001,ankleDrift<0.00001 else {throw failure("Mailbox growth moved ground or hinge")}
    var player=CharacterPlayback();player.play(.mailEmpty,at:0)
    player.request(.wave,at:1.5)
    guard player.playbackSnapshot(at:3.49).action == .mailEmpty,player.playbackSnapshot(at:3.51).action == .wave else {throw failure("Mailbox disappeared before closing")}
    let flap=LetterGeometry.mesh(.letterFlap).0
    var clearance:Float=100
    for frame in 0...120 {
        let pose=MailReadRoutine.sample(at:1.05+Double(frame)*0.80/120)
        let cue=pose.props.first {$0.kind == .letterFlap}!
        for vertex in flap {
            let p=(cue.rotation.act(SIMD3(vertex.position.x,vertex.position.y,vertex.position.z)*cue.scale)+cue.offset)/MailReadRoutine.paperScale
            if p.x>=(-0.28) && p.x<=0.28 {clearance=min(clearance,p.z-(0.018*sin(Float.pi*(p.x+0.28)/0.56)+0.001))}
        }
    }
    guard clearance>0.003 else {throw failure("Letter flap intersects the rear panel")}
    var reading=CharacterPlayback();reading.play(.mailRead,at:0,mode:.hold)
    guard reading.playbackSnapshot(at:10).action == .mailRead else {throw failure("Letter did not hold")}
    reading.finishRoutine(at:10)
    guard reading.playbackSnapshot(at:11.1).action == .idle else {throw failure("Letter failed to stow")}
    var interrupted=CharacterPlayback();interrupted.play(.mailRead,at:0,mode:.hold)
    interrupted.request(.wave,at:1.30)
    guard interrupted.playbackSnapshot(at:2.05).elapsed<3.85,
          interrupted.playbackSnapshot(at:3.11).action == .wave else {throw failure("Letter was interrupted during unfolding")}
    var next=CharacterPlayback();next.play(.mailRead,at:0,mode:.hold)
    next.request(.mailNext,at:5,mode:.hold)
    guard next.playbackSnapshot(at:5).action == .mailNext,
          abs(next.playbackSnapshot(at:5).elapsed-1.10)<0.00001 else {throw failure("Next letter replayed retrieval")}
    for frame in 0...180 {
        let snapshot=next.playbackSnapshot(at:5+Double(frame)/60)
        let pose=RoutineLibrary.sample(snapshot.action,at:snapshot.elapsed)
        guard pose.props.count==2,pose.props.allSatisfy({$0.visibility==1}) else {throw failure("Next letter lost its held panels")}
    }
    next.request(.mailRead,at:5.35,mode:.hold)
    guard next.playbackSnapshot(at:5.94).action == .mailNext,
          next.playbackSnapshot(at:5.96).action == .mailRead else {throw failure("Letter switch cut off unfolding")}
    var repeated=CharacterPlayback();repeated.play(.mailNext,at:0,mode:.hold)
    let folded=MailReadRoutine.sample(at:2.10).props[1].rotation
    for t in [5.0,7.0,10.0] {
        let snapshot=repeated.playbackSnapshot(at:t),pose=RoutineLibrary.sample(snapshot.action,at:snapshot.elapsed)
        guard abs(dot(pose.props[1].rotation.vector,folded.vector))>0.99999 else {throw failure("Held next-letter pass repeated its fold")}
    }
    repeated.request(.mailNext,at:10,mode:.hold)
    guard abs(repeated.playbackSnapshot(at:10).elapsed-1.10)<0.00001 else {throw failure("Repeat next-letter request failed")}
    repeated.setHeadphonesEnabled(true,at:10.2)
    guard repeated.playbackSnapshot(at:13.79).action == .mailNext,
          repeated.playbackSnapshot(at:13.81).action == .headphones else {throw failure("Accessory transfer skipped next-letter completion/stow")}
    var fingertipClearance:Float=100,fingertipSamples=0,heldTipClearance:Float=100
    for action in [Action.mailRead,.mailNext] {
        for frame in 0...252 {
            let t=Double(frame)/120
            rig.updateLiveAction(action,started:0,at:t,elapsed:t)
            let bones=rig.instances(yaw:0,pitch:0,at:t)
            let pose=RoutineLibrary.sample(action,at:t)
            let draws=motion.sample(action:action,started:0,at:t,cues:pose.props,rig:rig,bones:bones)
            if action == .mailRead,frame==252,let sheet=draws.first(where:{$0.kind == .letterFlap}) {
                for side in HandSide.allCases {
                    let tip=rig.attachmentFrame(.indexTip(side),axes:.character,bones:bones).columns.3
                    let p=sheet.model.inverse*tip
                    heldTipClearance=min(heldTipClearance,p.z-0.018*sin(Float.pi*p.x/0.56)-0.001)
                }
            }
            let turning=action == .mailRead ? (1.05...1.85).contains(t):(1.20...1.70).contains(t)
            if turning,let sheet=draws.first(where:{$0.kind == .letterFlap}) {
                let tip=rig.attachmentFrame(.indexTip(.left),axes:.character,bones:bones).columns.3
                let p=sheet.model.inverse*tip
                if p.x>0 && p.x<0.56 && abs(p.y)<0.32 {
                    fingertipSamples+=1
                    fingertipClearance=min(fingertipClearance,p.z-0.018*sin(Float.pi*p.x/0.56)-0.001)
                }
            }
        }
    }
    guard fingertipSamples>0,fingertipClearance>=0,heldTipClearance>=0 else {throw failure("Turning finger crosses the letter: \(fingertipClearance), samples \(fingertipSamples)")}
    let report:[String:Any]=["minimumLetterPanelClearance":clearance,"minimumHeldFingertipClearance":heldTipClearance,"minimumTurningFingertipClearance":fingertipClearance,"turningFingertipSamples":fingertipSamples,"nextLetterInPlacePassed":true,"nextLetterHoldAndRepeatPassed":true,"letterHoldAndStowPassed":true,"letterUnfoldBeforeReturnPassed":true,"maximumAnkleDrift":ankleDrift,"vertices":vertices,"triangles":triangles,"maximumGroundError":groundError,"maximumDoorHingeError":hingeError,"queuedActionWaitedForClose":true,"samples":421,"note":"Mesh winding, ground anchoring, door hinge and action scheduling checks. Not proof of original fidelity or comprehensive collision avoidance."]
    try FileManager.default.createDirectory(atPath:"Validation/Mail",withIntermediateDirectories:true)
    let data=try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys])
    try data.write(to:URL(fileURLWithPath:"Validation/Mail/checks.json"));print(String(decoding:data,as:UTF8.self))
}
