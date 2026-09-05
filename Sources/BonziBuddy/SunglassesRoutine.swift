import simd

// The original continued sequence includes the entrance; its return is separate.
// Geometry and grip coordinates are relative to the fitted head pivot.
enum SunglassesRoutine {
    static let duration=14.5
    static let holdRange=1.9..<12.6
    static let grip=SIMD3<Float>(-0.315,0.445,0.411)
    static let wornWrist=SIMD3<Float>(-0.315,0.74872,0.30915)
    private static let wristTrack=MotionTrack<SIMD3<Float>>([
        (0,[-0.45,-0.18,-0.15]), (0.6,[-0.45,-0.18,-0.15]),
        (0.9,[-0.55,-0.13,0.22]), (1.15,[-0.46,0.40,0.53]),
        (1.48,wornWrist), (12.95,wornWrist),
        (13.25,[-0.50,0.42,0.60]), (13.5,[-0.60,-0.13,0.22]),
        (13.8,[-0.45,-0.18,-0.15]), (14.5,[-0.45,-0.18,-0.15])
    ])
    private static let carryTilt=MotionTrack<Float>([(0,1),(0.9,1),(1.45,0),(12.95,0),(13.5,1),(14.5,1)])
    private static let look=MotionTrack<Float>([
        (0,0),(4.9,0),(5.1,0.16),(7.1,0.16),(7.4,0),
        (7.7,-0.16),(10.2,-0.16),(10.5,0),(14.5,0)
    ])
    static func sample(at t:Double)->RoutinePose {
        let enter=RoutineLibrary.smooth(t,0.05,0.45)*(1-RoutineLibrary.smooth(t,1.60,1.9))
        let adjust=RoutineLibrary.smooth(t,10.45,10.85)*(1-RoutineLibrary.smooth(t,12.1,12.5))
        let exit=RoutineLibrary.smooth(t,12.6,12.95)*(1-RoutineLibrary.smooth(t,14.05,14.5))
        let nudge=RoutineLibrary.smooth(t,11.0,11.25)*(1-RoutineLibrary.smooth(t,11.55,11.85))
        let lift=SIMD3<Float>(0,0.025*nudge,0.018*nudge)
        let wrist=wristTrack.sample(at:t)+lift
        let hand=HandIntent(wrist:wrist,fingers:[0.6,0.15,0.2],palm:[0,0,1],openness:1,weight:max(enter,max(adjust,exit)),grip:0.55)
        let tilt=carryTilt.sample(at:t)
        let rotation=simd_quatf(angle:-0.5*tilt,axis:[0,0,1])*simd_quatf(angle:0.5*tilt,axis:[1,0,0])
        let carry=PropAnchor.transformed(.attachment(.wrist(.left)),offset:-rotation.act(grip),rotation:rotation)
        let wear=PropAnchor.transformed(.attachment(.head,axes:.joint),offset:lift,rotation:simd_quatf(angle:-0.025*nudge,axis:[0,0,1]))
        let attached=RoutineLibrary.smooth(t,1.35,1.55)*(1-RoutineLibrary.smooth(t,13.0,13.18))
        let reveal=RoutineLibrary.smooth(t,0.65,0.85)*(1-RoutineLibrary.smooth(t,13.75,14.0))
        let prop=PropCue(id:"sunglasses",kind:.sunglasses,anchor:.blend(carry,wear,weight:attached),offset:.zero,visibility:reveal)
        return RoutinePose(hands:[.left:hand],headYaw:look.sample(at:t),face:FacialIntent(eyeClosure:0.45*attached,smileOffset:0.10*RoutineLibrary.smooth(t,1.7,1.9)*(1-RoutineLibrary.smooth(t,12.6,12.9))),props:reveal>0 ? [prop]:[])
    }
}
