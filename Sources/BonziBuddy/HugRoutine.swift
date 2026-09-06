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
        let rightWeight=RoutineLibrary.smooth(t,0.30,0.68)*(1-RoutineLibrary.smooth(t,3.12,3.36))
        let active=RoutineLibrary.smooth(t,0.10,0.60)*returning
        let clearance=0.445*(1-RoutineLibrary.smooth(t,0.38,0.70))
        let lift=0.21*(1-RoutineLibrary.smooth(t,0.30,0.60))+0.21*RoutineLibrary.smooth(t,3.38,3.52)
        let withdraw=RoutineLibrary.smooth(t,2.94,3.08)
        let lateReturn=RoutineLibrary.smooth(t,3.38,3.52)
        let approach=0.225*(1-RoutineLibrary.smooth(t,0.30,0.50))+0.15*withdraw+0.075*lateReturn
        let rightRetreat=0.20*RoutineLibrary.smooth(t,3.0,3.16)*(1-RoutineLibrary.smooth(t,3.36,3.54))
        let leftRetreat=0.345*withdraw+0.1*lateReturn
        let rightClearance=max(0,clearance-0.1*(1-RoutineLibrary.smooth(t,0.54,0.70)))
        let rightLower=0.22*(1-RoutineLibrary.smooth(t,0.47,0.67))
        let left=HandIntent(wrist:.zero,fingers:[0.10,-0.40,-1],palm:[-0.5,0,-1],
                            targetSpace:.torso,
                            openness:0.70,weight:leftWeight,grip:0.30,fingersTogether:0.85,thumbFold:1,
                            palmContact:[0.43-approach,0.171+lift,0.28+clearance+leftRetreat],
                            shoulderOffset:[-0.11,0.02,0.23],
                            elbowBend:[-1,-0.15-0.25*withdraw+0.25*lateReturn,0.50])
        let right=HandIntent(wrist:.zero,fingers:[-0.10,0.30,-1],palm:[0.5,0,-1],
                             targetSpace:.torso,
                             openness:0.70,weight:rightWeight,grip:0.30,fingersTogether:0.85,thumbFold:1,
                             palmContact:[-0.39+0.2*RoutineLibrary.smooth(t,3.0,3.14),-0.029-rightLower-0.20*RoutineLibrary.smooth(t,3.0,3.12),0.35+rightClearance+rightRetreat],
                            shoulderOffset:[0.11,0.03,0.18],
                            elbowBend:[1,-0.65,0.60])
        let sway=rock.sample(at:t)*active,closure=lids.sample(at:t)
        return RoutinePose(hands:[.left:left,.right:right],torsoTilt:-0.06*active-0.08*sway,headTilt:-0.03*sway,
                           face:FacialIntent(eyeClosure:closure,smileOffset:0.08*active,
                                             individualBrowLower:[0.08*closure,0.08*closure]),
                           stance:StanceIntent(pelvisOffset:[0.018*sway,-0.015*active,0]))
    }
}
