import simd

// Original Wink: thirteen frames, 1.80 seconds. Turn, close the left eye,
// reopen, then return; hands and feet keep their shared resting pose.
enum WinkRoutine {
    static let duration=1.80
    private static let turn=MotionTrack<Float>([
        (0,0),(0.10,0),(0.40,1),(1.05,1),(1.40,0.8),(1.70,0),(1.80,0)
    ])
    private static let closure=MotionTrack<Float>([
        (0,0),(0.40,0),(0.55,0.5),(0.65,1),(0.90,1),(0.95,0.5),(1.05,0),(1.80,0)
    ])
    static func sample(at t:Double)->RoutinePose {
        let facing=turn.sample(at:t),lid=closure.sample(at:t)
        return RoutinePose(headYaw:-0.30*facing-0.20*lid,headTilt:0.035*facing,
                           face:FacialIntent(smileOffset:0.04*facing,individualEyeClosure:[lid,0]))
    }
}
