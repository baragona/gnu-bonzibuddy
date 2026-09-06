import simd

// Original MailRead (3.85s) and MailReturn (1.00s), with a held reading region.
enum MailReadRoutine {
    static let duration=4.85
    static let paperScale:Float=1.25
    static let holdRange=2.10..<3.85
    static let continuation=RoutineContinuation(family:.mail,entryElapsed:2.10,acceptsFrom:0..<3.85,delay:{max(0,2.10-$0)})
    private static let center=MotionTrack<SIMD3<Float>>([
        (0,[-0.60,-0.40,-0.22]),(0.55,[-0.60,-0.40,-0.22]),(0.85,[-0.42,-0.25,0.32]),
        (1.10,[0,-0.06,0.48]),(3.85,[0,-0.06,0.48]),(4.10,[-0.42,-0.25,0.32]),
        (4.40,[-0.60,-0.40,-0.22]),(4.85,[-0.60,-0.40,-0.22])
    ])
    static func sample(at t:Double)->RoutinePose {
        let origin=center.sample(at:t),anchor=PropAnchor.transformed(.character,offset:origin,rotation:simd_quatf(angle:0,axis:[0,1,0]))
        let visible=RoutineLibrary.smooth(t,0.55,0.75)*(1-RoutineLibrary.smooth(t,4.25,4.45))
        let opened=RoutineLibrary.smooth(t,1.05,1.35)*(1-RoutineLibrary.smooth(t,1.50,1.85))
        let rotation=simd_quatf(angle:-Float.pi*opened,axis:[0,1,0])
        let hinge=SIMD3<Float>(-0.28,0,0.006)
        let props=visible>0 ? [PropCue(id:"mail.letter.back",kind:.letterBack,anchor:anchor,offset:.zero,scale:SIMD3(repeating:paperScale),visibility:visible),PropCue(id:"mail.letter.flap",kind:.letterFlap,anchor:anchor,offset:hinge*visible*paperScale,rotation:rotation,scale:SIMD3(repeating:paperScale),visibility:visible)]:[]
        let active=RoutineLibrary.smooth(t,0.15,0.55)*(1-RoutineLibrary.smooth(t,4.45,4.85))
        let held=RoutineLibrary.smooth(t,0.80,1.10)*(1-RoutineLibrary.smooth(t,3.85,4.15))
        var left=SIMD3<Float>(-0.38,0,0.04)
        left += (hinge+rotation.act(SIMD3<Float>(0.50,0,0.03))+SIMD3<Float>(-0.10,0,0.04)-left)*opened
        left=SIMD3<Float>(-0.10,-0.03,0.06)+(left*paperScale-SIMD3<Float>(-0.10,-0.03,0.06))*held
        let hands:[HandSide:HandIntent]=[
            .left:HandIntent(wrist:origin+left,fingers:[1,0,0],palm:[0,0,-1],weight:active,grip:0.18),
            .right:HandIntent(wrist:origin+SIMD3<Float>(0.38,0,0.04)*paperScale,fingers:[-1,0,0],palm:[0,0,-1],weight:held,grip:0.18)
        ]
        let reading=RoutineLibrary.smooth(t,1.85,2.10)*(1-RoutineLibrary.smooth(t,3.85,4.10))
        return RoutinePose(hands:hands,headPitch:0.08*reading,face:FacialIntent(eyeClosure:0.12*reading,gaze:[0.20*sin(Float(t-2.10)*2*Float.pi/1.75)*reading,-0.60*reading]),props:props)
    }
}
