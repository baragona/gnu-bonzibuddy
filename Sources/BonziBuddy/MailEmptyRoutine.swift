import simd

// Original MailCheck (0.90s) followed by MailCheckEmpty (2.60s).
enum MailEmptyRoutine {
    static let duration=3.50
    static let origin=MailboxScene.origin
    static let rotation=MailboxScene.rotation
    static func sample(at t:Double)->RoutinePose {
        let visible=RoutineLibrary.smooth(t,0.05,0.35)*(1-RoutineLibrary.smooth(t,2.90,3.20))
        let door=RoutineLibrary.smooth(t,0.45,0.85)*(1-RoutineLibrary.smooth(t,2.30,2.75))
        let props=MailboxScene.cues(visibility:visible,opening:door)
        let inspect=RoutineLibrary.smooth(t,0.95,1.35)*(1-RoutineLibrary.smooth(t,2.05,2.55))
        let reach=max(RoutineLibrary.smooth(t,0.35,0.45)*(1-RoutineLibrary.smooth(t,0.85,1.10)),RoutineLibrary.smooth(t,2.20,2.30)*(1-RoutineLibrary.smooth(t,2.75,2.90)))
        let doorCenter=origin+rotation.act(SIMD3<Float>(0.265,-0.155,0)+simd_quatf(angle:-2.80*door,axis:[0,0,1]).act(SIMD3<Float>(0,0.155,0)))
        let hand=HandIntent(wrist:doorCenter+SIMD3<Float>(0.22,0.03,0.08),fingers:[-1,0,0],palm:[0,0,-1],weight:reach,grip:0.18)
        return RoutinePose(hands:[.left:hand],headYaw:-0.90*inspect,headTilt:0.06*inspect,headPitch:0.04*inspect,face:FacialIntent(eyeClosure:0.10*inspect,gaze:[-0.65*inspect,-0.08*inspect]),props:props,stance:StanceIntent(pelvisOffset:[0,-0.18*inspect,0]))
    }
}
