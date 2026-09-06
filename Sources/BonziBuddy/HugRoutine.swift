import simd

// Original Hug has a 100% branch from frame 24 to 26, skipping the duplicate
// 100 ms hold frame 25. Played duration is 3.64 s (stored-frame sum: 3.74 s).
enum HugRoutine {
    static let duration=3.64
    private static let rock=MotionTrack<Float>([
        (0,0),(1.14,0),(1.32,1),(1.68,-1),(2.04,1),(2.34,0),(3.64,0)
    ])
    private static let lids=MotionTrack<Float>([
        (0,0),(0.40,0),(0.50,0.5),(0.60,1),(2.94,1),(3.04,0.5),(3.14,0),(3.64,0)
    ])
    static func sample(at t:Double)->RoutinePose {
        let returning=1-RoutineLibrary.smooth(t,3.04,3.54)
        let leftWeight=RoutineLibrary.smooth(t,0.10,0.50)*(1-RoutineLibrary.smooth(t,3.34,3.64))
        let rightWeight=RoutineLibrary.smooth(t,0.30,0.68)*(1-RoutineLibrary.smooth(t,3.00,3.32))
        let active=RoutineLibrary.smooth(t,0.10,0.60)*returning
        let clearance=0.18*(1-RoutineLibrary.smooth(t,0.28,0.58))
        let rightRetreat=0.20*RoutineLibrary.smooth(t,3.0,3.16)*(1-RoutineLibrary.smooth(t,3.36,3.54))
        let leftRetreat=0.30*RoutineLibrary.smooth(t,3.26,3.40)*(1-RoutineLibrary.smooth(t,3.54,3.64))
        let left=HandIntent(wrist:.zero,fingers:[0.10,-0.40,-1],palm:[-0.5,0,-1],
                            openness:0.70,weight:leftWeight,grip:0.30,fingersTogether:0.85,thumbFold:0.45,
                            palmContact:[0.39,0.20+0.12*RoutineLibrary.smooth(t,3.26,3.40),0.28+clearance+leftRetreat],shoulderOffset:[-0.07,0.02,0.18],elbowBend:[-1,-0.15,0.60])
        let right=HandIntent(wrist:.zero,fingers:[-0.10,0.30,-1],palm:[0.5,0,-1],
                             openness:0.70,weight:rightWeight,grip:0.30,fingersTogether:0.85,thumbFold:0.45,
                             palmContact:[-0.39,-0.04-0.20*RoutineLibrary.smooth(t,3.0,3.12),0.35+clearance+rightRetreat],shoulderOffset:[0.07,0,0.18],elbowBend:[1,-0.65,0.60])
        let sway=rock.sample(at:t)*active,closure=lids.sample(at:t)
        return RoutinePose(hands:[.left:left,.right:right],headTilt:0.11*sway,
                           face:FacialIntent(eyeClosure:closure,smileOffset:0.08*active,
                                             individualBrowLower:[0.08*closure,0.08*closure]),
                           stance:StanceIntent(pelvisOffset:[-0.018*sway,-0.015*active,0]))
    }
}
