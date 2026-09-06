import simd

// Original Giggle: 22 frames over 2.30 seconds. The three repeated source
// poses supply small laugh pulses; feet stay planted and hands remain at rest.
enum GiggleRoutine {
    static let duration=2.30
    private static let pulse=MotionTrack<Float>([
        (0,0),(0.30,0),(0.40,1),(0.50,0),(0.60,0),(0.70,1),(0.80,0),
        (0.90,0),(1.00,1),(1.10,0),(1.20,0),(1.30,1),(1.40,0),
        (1.50,0),(1.60,1),(1.70,0),(1.80,0),(2.30,0)
    ])
    private static let lids=MotionTrack<Float>([
        (0,0),(0.10,0),(0.20,0.5),(0.30,1),(1.90,1),(2.00,0.5),(2.10,0),(2.30,0)
    ])
    static func sample(at t:Double)->RoutinePose {
        let active=RoutineLibrary.smooth(t,0,0.30)*(1-RoutineLibrary.smooth(t,1.90,2.20))
        let beat=pulse.sample(at:t)*active,closure=lids.sample(at:t)
        return RoutinePose(headPitch:0.015*beat,
                           face:FacialIntent(eyeClosure:closure,smileOffset:0.80*active,
                                             individualBrowLower:[0.12*closure,0.12*closure]),
                           stance:StanceIntent(pelvisOffset:[0,-0.025*active-0.012*beat,0]))
    }
}
