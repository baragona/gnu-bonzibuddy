import simd

// Original MailCheck (0.90s) followed by MailCheckEmpty (2.60s).
enum MailEmptyRoutine {
    static let duration=3.50
    static let origin=SIMD3<Float>(-1.05,0.10,0)
    static let rotation=simd_quatf(angle:-0.35,axis:SIMD3<Float>(0,1,0))
    static func sample(at t:Double)->RoutinePose {
        let visible=RoutineLibrary.smooth(t,0.05,0.35)*(1-RoutineLibrary.smooth(t,2.90,3.20))
        let root=PropAnchor.transformed(.character,offset:origin,rotation:rotation)
        // Grow from the ground, keeping the post base planted during appearance.
        let anchor=PropAnchor.transformed(root,offset:[0,-1.0*(1-visible),0],rotation:simd_quatf(angle:0,axis:[0,1,0]))
        let door=RoutineLibrary.smooth(t,0.45,0.85)*(1-RoutineLibrary.smooth(t,2.30,2.75))
        var props:[PropCue]=[]
        if visible>0 {
            props=[PropCue(id:"mail.box",kind:.mailbox,anchor:anchor,offset:.zero,visibility:visible),
                   PropCue(id:"mail.door",kind:.mailboxDoor,anchor:anchor,offset:SIMD3<Float>(0.265,-0.155,0)*visible,rotation:simd_quatf(angle:-2.80*door,axis:[0,0,1]),visibility:visible),
                   PropCue(id:"mail.flag",kind:.bananaFruit,anchor:anchor,offset:SIMD3<Float>(0.12,0.16,0.12)*visible,scale:[0.32,0.30,0.32],visibility:visible,deformation:.fruit(remaining:1)),
                   PropCue(id:"mail.flag.peel",kind:.bananaPeel,anchor:anchor,offset:SIMD3<Float>(0.12,0.16,0.12)*visible,scale:[0.32,0.30,0.32],visibility:visible,deformation:.peel(openings:.zero))]
        }
        let inspect=RoutineLibrary.smooth(t,0.95,1.35)*(1-RoutineLibrary.smooth(t,2.05,2.55))
        let reach=max(RoutineLibrary.smooth(t,0.35,0.45)*(1-RoutineLibrary.smooth(t,0.85,1.10)),RoutineLibrary.smooth(t,2.20,2.30)*(1-RoutineLibrary.smooth(t,2.75,2.90)))
        let doorCenter=origin+rotation.act(SIMD3<Float>(0.265,-0.155,0)+simd_quatf(angle:-2.80*door,axis:[0,0,1]).act(SIMD3<Float>(0,0.155,0)))
        let hand=HandIntent(wrist:doorCenter+SIMD3<Float>(0.22,0.03,0.08),fingers:[-1,0,0],palm:[0,0,-1],weight:reach,grip:0.18)
        return RoutinePose(hands:[.left:hand],headYaw:-0.90*inspect,headTilt:0.06*inspect,headPitch:0.04*inspect,face:FacialIntent(eyeClosure:0.10*inspect,gaze:[-0.65*inspect,-0.08*inspect]),props:props,stance:StanceIntent(pelvisOffset:[0,-0.18*inspect,0]))
    }
}
