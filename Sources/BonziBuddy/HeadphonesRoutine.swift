import simd

// ACS 3.0.7: 12.02 seconds continued, 2.10 seconds return. Both hands carry
// the inverted headset, turn it upright, and release after it seats on the head.
enum HeadphonesRoutine {
    static let duration=14.12
    static let holdRange=2.0..<12.02
    static let headOrigin=SIMD3<Float>(0,0.30372,-0.10185)
    private static let center=MotionTrack<SIMD3<Float>>([
        (0,[-0.10,-0.40,-0.22]),(0.55,[-0.10,-0.40,-0.22]),
        (0.80,[0,-0.30,0.32]),(1.05,[0,0.04,0.43]),
        (1.35,[0,0.35,0.10]),(1.55,headOrigin),
        (12.02,headOrigin),(12.62,headOrigin),(12.92,[0,0.28,0.35]),
        (13.17,[0,-0.18,0.42]),(13.47,[-0.10,-0.40,-0.22]),(14.12,[-0.10,-0.40,-0.22])
    ])
    private static let tilt=MotionTrack<Float>([(0,.pi),(0.80,.pi),(1.35,0),(12.62,0),(13.17,.pi),(14.12,.pi)])
    static func sample(at t:Double)->RoutinePose {
        let attached=RoutineLibrary.smooth(t,1.35,1.55)*(1-RoutineLibrary.smooth(t,12.62,12.82))
        let visible=RoutineLibrary.smooth(t,0.52,0.72)*(1-RoutineLibrary.smooth(t,13.35,13.57))
        let rotation=simd_quatf(angle:tilt.sample(at:t),axis:[1,0,0])
        let origin=center.sample(at:t)
        let carry=PropAnchor.transformed(.character,offset:origin,rotation:rotation)
        let wear=PropAnchor.attachment(.head,axes:.joint)
        let prop=PropCue(id:"headphones",kind:.headphones,anchor:.blend(carry,wear,weight:attached),offset:.zero,visibility:visible)
        let handWeight=max(RoutineLibrary.smooth(t,0.05,0.45)*(1-RoutineLibrary.smooth(t,1.65,2.0)),RoutineLibrary.smooth(t,12.02,12.47)*(1-RoutineLibrary.smooth(t,13.65,14.12)))
        var hands:[HandSide:HandIntent]=[:]
        for side in [HandSide.left,.right] {
            let wrist=origin+rotation.act(SIMD3<Float>(side.sign*0.505,0.245,0.085))
            hands[side]=HandIntent(wrist:wrist,fingers:rotation.act([-side.sign,0.25,0]),palm:rotation.act([0,0,1]),openness:0.7,weight:handWeight,grip:0.3)
        }
        let listening=RoutineLibrary.smooth(t,5.3,6.2)*(1-RoutineLibrary.smooth(t,11.62,12.02))
        let sway=Float(sin((t-6.2)*4))*0.065*listening
        return RoutinePose(hands:hands,headTilt:sway,headPitch:0.035*listening,face:FacialIntent(eyeClosure:listening),props:visible>0 ? [prop]:[])
    }
}
