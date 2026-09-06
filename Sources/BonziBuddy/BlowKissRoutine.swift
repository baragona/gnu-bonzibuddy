import simd

// Original BlowKiss: 2.08 seconds. Bring a hand to the lips, rotate it
// palm-up toward the viewer, hold the blown kiss, and return. No heart prop.
enum BlowKissRoutine {
    static let duration=2.08
    private static let lids=MotionTrack<Float>([
        (0,0),(0.10,0),(0.20,0.5),(0.30,1),(0.40,0.5),(0.50,0),(2.08,0)
    ])
    static func sample(at t:Double)->RoutinePose {
        let active=RoutineLibrary.smooth(t,0.10,0.50)*(1-RoutineLibrary.smooth(t,1.58,1.98))
        let release=RoutineLibrary.smooth(t,0.80,1.28)
        let turn=simd_quatf(angle:release * .pi/2,axis:[1,0,0])
        let fingers=normalize(SIMD3<Float>(1-release,0.55*(1-release),release))
        let palm=turn.act(SIMD3<Float>(0,0,-1))
        var contact=SIMD3<Float>(-0.06,0.35,0.48)+(SIMD3<Float>(-0.16,0.32,0.62)-SIMD3<Float>(-0.06,0.35,0.48))*release
        let approach=1-RoutineLibrary.smooth(t,0.35,0.50)
        contact+=SIMD3<Float>(-0.18,0,0.30)*approach
        let left=HandIntent(wrist:.zero,fingers:fingers,palm:palm,weight:active,fingersTogether:0.85,thumbFold:0.8,palmContact:contact,elbowBend:[-1,-0.70,0.45])
        return RoutinePose(hands:[.left:left,.right:RoutineLibrary.handOnBelly(.right,weight:active)],
                           headPitch:(-0.06+0.09*release)*active,
                           face:FacialIntent(eyeClosure:lids.sample(at:t),smileOffset:-0.20*active,mouthPucker:0.60*active))
    }
}
