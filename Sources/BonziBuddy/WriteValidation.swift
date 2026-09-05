import Foundation
import simd

func validateWrite() throws {
    var vertices=0,triangles=0
    for kind in [PropKind.writingPad,.pencil] {
        let mesh=WritingGeometry.mesh(kind)
        for i in stride(from:0,to:mesh.1.count,by:3) {
            let v=(0..<3).map {mesh.0[Int(mesh.1[i+$0])]}
            let p=v.map {SIMD3<Float>($0.position.x,$0.position.y,$0.position.z)}
            let n=cross(p[1]-p[0],p[2]-p[0])
            guard length(n)>1e-10,dot(n,SIMD3(v[0].normal.x,v[0].normal.y,v[0].normal.z))>0 else {throw failure("Invalid writing prop triangle")}
        }
        vertices += mesh.0.count;triangles += mesh.1.count/3
    }
    var tipError:Float=0
    for frame in 0...60 {
        let t=2.20+Double(frame)*0.5/60,pose=WriteRoutine.sample(at:t)
        let pad=pose.props.first {$0.kind == .writingPad}!,pencil=pose.props.first {$0.kind == .pencil}!
        guard case let .transformed(_,origin,rotation)=pad.anchor else {throw failure("Pad frame missing")}
        let local=rotation.inverse.act(pencil.offset-origin)
        tipError=max(tipError,abs(local.z-WritingGeometry.paperZ-0.002))
        guard abs(local.x)<0.285,abs(local.y)<0.205 else {throw failure("Pencil leaves writing surface")}
    }
    guard tipError<0.00001 else {throw failure("Pencil tip lost pad contact")}
    let start=WriteRoutine.sample(at:4.30),end=WriteRoutine.sample(at:5.50)
    for side in HandSide.allCases {
        guard length(start.hands[side]!.wrist-end.hands[side]!.wrist)<0.00001 else {throw failure("Writing loop hand jump")}
    }
    guard length(start.props[1].offset-end.props[1].offset)<0.00001 else {throw failure("Writing loop pencil jump")}
    var player=CharacterPlayback();player.play(.write,at:0,mode:.hold)
    player.request(.wave,at:4.70)
    guard player.playbackSnapshot(at:5.40).elapsed<5.50,player.playbackSnapshot(at:6.94).action == .write,player.playbackSnapshot(at:6.96).action == .wave else {throw failure("Writing handoff cut off stroke or stow")}
    var variant=CharacterPlayback();variant.play(.write,at:0,mode:.hold)
    variant.request(.writePause,at:4.70,mode:.hold)
    guard variant.playbackSnapshot(at:5.49).action == .write,
          variant.playbackSnapshot(at:5.51).action == .writePause else {throw failure("Pause did not wait for the stroke")}
    variant.request(.write,at:6.0,mode:.hold)
    guard variant.playbackSnapshot(at:6.49).action == .writePause,variant.playbackSnapshot(at:6.50).action == .write,
          abs(variant.playbackSnapshot(at:6.50).elapsed-4.30)<0.000001 else {throw failure("Resume replayed retrieval")}
    for frame in 0...120 {
        let snapshot=variant.playbackSnapshot(at:6.5+Double(frame)/120)
        let pose=RoutineLibrary.sample(snapshot.action,at:snapshot.elapsed)
        guard pose.props.count==2,pose.props.allSatisfy({$0.visibility==1}) else {throw failure("Variant switch lost the pad or pencil")}
    }
    let pause=WritePauseRoutine.sample(at:1.90)
    for side in HandSide.allCases {
        guard length(pause.hands[side]!.wrist-start.hands[side]!.wrist)<0.00001 else {throw failure("Shared writing seam hand mismatch")}
    }
    guard length(pause.props[1].offset-start.props[1].offset)<0.00001 else {throw failure("Shared writing seam pencil mismatch")}
    // A reversal partway through lowering must begin from the displayed prop pose.
    for t in stride(from:1.95,through:2.85,by:0.05) {
        let exit=WritePauseRoutine.continuation.exitElapsed(t)!
        let before=WritePauseRoutine.sample(at:t),after=WritePauseRoutine.sample(at:exit)
        guard length(before.props[1].offset-after.props[1].offset)<0.00001,
              length(before.hands[.left]!.wrist-after.hands[.left]!.wrist)<0.00001,
              abs(before.headYaw-after.headYaw)<0.00001 else {throw failure("Pause reversal jumped")}
    }
    var early=CharacterPlayback();early.play(.write,at:0,mode:.hold)
    early.request(.writePause,at:0.4,mode:.hold)
    guard early.playbackSnapshot(at:1.89).action == .write,
          early.playbackSnapshot(at:1.91).action == .writePause else {throw failure("Pause interrupted retrieval")}
    variant.setHeadphonesEnabled(true,at:7.0)
    guard variant.playbackSnapshot(at:9.14).action == .write,
          variant.playbackSnapshot(at:9.16).action == .headphones else {throw failure("Accessory transfer skipped resumed writing stow")}
    var cancelled=CharacterPlayback();cancelled.play(.write,at:0,mode:.hold)
    cancelled.request(.writePause,at:4.70,mode:.hold)
    cancelled.finishRoutine(at:5.0)
    guard cancelled.playbackSnapshot(at:5.6).action == .write,
          cancelled.playbackSnapshot(at:7.0).action == .idle else {throw failure("Return to rest failed to cancel queued continuation")}
    var returning=CharacterPlayback();returning.play(.writePause,at:0,mode:.hold)
    returning.request(.write,at:3.0,mode:.hold)
    let beforeStop=returning.playbackSnapshot(at:3.25)
    returning.finishRoutine(at:3.25)
    let afterStop=returning.playbackSnapshot(at:3.25)
    guard beforeStop.action == afterStop.action,abs(beforeStop.elapsed-afterStop.elapsed)<0.00001,
          returning.playbackSnapshot(at:5.0).action == .idle else {throw failure("Stopping a continuation replayed its return phase")}
    var repeated=CharacterPlayback();repeated.play(.writePause,at:0,mode:.hold)
    repeated.request(.write,at:3.0,mode:.hold);repeated.request(.write,at:3.25,mode:.hold)
    guard repeated.playbackSnapshot(at:3.49).action == .writePause,
          repeated.playbackSnapshot(at:3.50).action == .write else {throw failure("Repeated resume restarted the exit")}
    let report:[String:Any]=["smoothPauseReversalPassed":true,"returnDuringContinuationPassed":true,"repeatedResumePassed":true,"inPlacePauseResumePassed":true,"queuedContinuationCancellationPassed":true,"retrievalAndAccessoryHandoffsPassed":true,"vertices":vertices,"triangles":triangles,"maximumPencilPlaneError":tipError,"contactSamples":61,"holdSeamPassed":true,"strokeAndStowHandoffPassed":true,"note":"Pencil contact is measured against the authored pad plane. These checks do not establish finger contact, full-body collision avoidance, or original visual identity."]
    try FileManager.default.createDirectory(atPath:"Validation/Writing",withIntermediateDirectories:true)
    let data=try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys])
    try data.write(to:URL(fileURLWithPath:"Validation/Writing/checks.json"));print(String(decoding:data,as:UTF8.self))
}
