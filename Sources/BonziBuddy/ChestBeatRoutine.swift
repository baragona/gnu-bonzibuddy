import simd

// Original GetAttention: fifteen 100 ms frames, then a zero-duration rest frame.
// Each track is the outward swing of one fist; the opposite hand stays at the chest.
enum ChestBeatRoutine {
    static let duration=1.50
    private static let left=MotionTrack<Float>([
        (0,0),(0.40,0),(0.60,1),(0.80,0),(1.00,1),(1.20,0),(1.50,0)
    ])
    private static let right=MotionTrack<Float>([
        (0,0),(0.20,0.35),(0.30,1),(0.40,1),(0.60,0),(0.80,1),(1.00,0),(1.20,0.35),(1.30,0),(1.50,0)
    ])
    static func sample(at t:Double)->RoutinePose {
        let active=RoutineLibrary.smooth(t,0.05,0.20)*(1-RoutineLibrary.smooth(t,1.20,1.50))
        let a=left.sample(at:t),b=right.sample(at:t)
        var hands:[HandSide:HandIntent]=[:]
        for side in HandSide.allCases {
            let swing=side == .left ? a:b
            let chest=SIMD3<Float>(side.sign*0.12,0.15,0.35)
            let raised=SIMD3<Float>(side.sign*0.98,0.27,0.10)
            hands[side]=HandIntent(wrist:chest+(raised-chest)*swing,
                                  fingers:[side.sign*(-1+1.25*swing),swing,0],palm:[0,0,-1],
                                  weight:active,fist:active)
        }
        let sway=(b-a)*active
        return RoutinePose(hands:hands,headTilt:-0.04*sway,headPitch:-0.04*active,
                           face:FacialIntent(jawOpening:0.08*active,smileOffset:0.06*active),
                           stance:StanceIntent(pelvisOffset:[0.012*sway,0.012*(a+b)*active,0]))
    }
}
