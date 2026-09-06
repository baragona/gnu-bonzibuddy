import simd

// Original Shoosh: 15 frames, 1.95 seconds. The 0.5...1.45 hold includes
// an authored blink; there is no separate continued/return animation.
enum ShushRoutine {
    static let duration=1.95
    private static let lids=MotionTrack<Float>([
        (0,0),(0.10,0.5),(0.20,1),(0.30,0.5),(0.40,0),
        (0.70,0),(0.80,0.5),(0.90,1),(1.00,0.5),(1.10,0),
        (1.45,0),(1.55,0.5),(1.65,1),(1.75,0.5),(1.85,0),(1.95,0)
    ])
    static func sample(at t:Double)->RoutinePose {
        let active=RoutineLibrary.smooth(t,0.10,0.50)*(1-RoutineLibrary.smooth(t,1.45,1.85))
        let approach=RoutineLibrary.smooth(t,0.20,0.50)*(1-RoutineLibrary.smooth(t,1.45,1.70))
        let target=SIMD3<Float>(-0.025,0.40,0.465)+SIMD3<Float>(-0.06,-0.10,0.09)*(1-approach)
        let hand=HandIntent(wrist:.zero,fingers:[0,1,-0.45],palm:[0,0,-1],weight:active,pointing:true,indexTipContact:target)
        return RoutinePose(hands:[.left:hand,.right:RoutineLibrary.handOnBelly(.right,weight:active)],
                           face:FacialIntent(eyeClosure:lids.sample(at:t),smileOffset:-0.16*active,mouthPucker:0.22*active))
    }
}
