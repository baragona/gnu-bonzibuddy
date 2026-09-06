import simd

// Original Banana: two bites, chewing, then throw away the peel.
// BananaMiss: launch the fruit out of its peel, miss, wait, look around, discard.
enum BananaRoutine {
    static let size:Float=0.60
    static let fruitRelease=1.45
    static func duration(miss:Bool)->Double {miss ? 11.33:7.2}
    static func peelRelease(miss:Bool)->Double {miss ? 10.60:5.60}
    private static let entry:[(Double,SIMD3<Float>)]=[
        (0,[-0.42,-0.22,-0.14]), (0.5,[-0.42,-0.22,-0.14]), (0.95,[-0.78,0.24,0.48])
    ]
    private static let eatingBase=MotionTrack<SIMD3<Float>>(entry+[
        (1.5,[-0.78,0.24,0.48]), (1.75,[-0.78,0.07,0.60]),
        (2.0,[-0.51,0.08,0.30]), (2.25,[-0.51,0.08,0.30]),
        (2.6,[-0.75,0.16,0.56]), (3.85,[-0.75,0.16,0.56]),
        (4.2,[-0.21,0.10,0.30]), (4.4,[-0.21,0.10,0.30]),
        (4.75,[-0.70,0.20,0.50]), (5.2,[-0.70,0.20,0.50]),
        (5.35,[-0.73,0.02,0.55]), (5.60,[-0.72,0.47,0.52])
    ])
    private static let missedBase=MotionTrack<SIMD3<Float>>(entry+[
        (1.2,[-0.78,0.24,0.48]), (1.32,[-0.72,0.06,0.58]),
        (1.45,[-0.70,0.36,0.66]), (1.75,[-0.75,0.25,0.62]),
        (3.15,[-0.75,0.25,0.62]), (3.55,[-0.20,0.11,0.52]),
        (9.95,[-0.20,0.11,0.52]), (10.25,[-0.67,-0.05,0.56]), (10.60,[-0.72,0.47,0.52])
    ])
    private static let eatingAngle=MotionTrack<Float>([
        (0,0), (1.7,0), (2.0,-0.95), (2.25,-0.95), (2.6,0),
        (3.85,0), (4.2,-0.80), (4.4,-0.80), (4.75,0), (5.35,0.25), (5.6,-0.4)
    ])
    private static let missedAngle=MotionTrack<Float>([
        (0,0), (1.2,0), (1.32,0.25), (1.45,-0.15), (1.8,0), (10.25,0.3), (10.6,-0.4)
    ])
    private static let eatingJaw=MotionTrack<Float>([
        (0,0), (1.8,0), (2.02,0.65), (2.15,0.65), (2.38,0),
        (4.0,0), (4.20,0.60), (4.35,0.60), (4.55,0), (7.2,0)
    ])
    private static let missedJaw=MotionTrack<Float>([(0,0),(1.45,0),(1.7,0.8),(3.12,0.8),(3.5,0),(11.33,0)])
    private static let missedPitch=MotionTrack<Float>([(0,0),(1.5,0),(1.9,-0.65),(3.15,-0.65),(3.5,0),(11.33,0)])
    private static let missedLook=MotionTrack<Float>([
        (0,0), (4.1,0), (4.5,0.5), (5.0,0.5), (5.3,-0.5), (6.4,-0.5),
        (6.8,0), (7.85,0), (8.15,0.25), (8.75,0.25), (9.05,0), (11.33,0)
    ])
    static func base(at t:Double,miss:Bool)->SIMD3<Float> {(miss ? missedBase:eatingBase).sample(at:t)}
    static func angle(at t:Double,miss:Bool)->Float {(miss ? missedAngle:eatingAngle).sample(at:t)}
    static func fruitFlight(_ t:Double)->SIMD3<Float> {
        let p=Float(max(0,t-fruitRelease))
        // The fruit passes in front of, then beside, the head on the missed toss.
        return base(at:fruitRelease,miss:true)+SIMD3<Float>(1.75*p,2.7*p-3.2*p*p,0.48*p)
    }
    static func peelFlight(_ t:Double,miss:Bool)->SIMD3<Float> {
        let p=Float(max(0,t-peelRelease(miss:miss)))
        return base(at:peelRelease(miss:miss),miss:miss)+SIMD3<Float>(0.48*p,2.1*p-2.2*p*p,-1.4*p)
    }
    static func sample(at t:Double,miss:Bool)->RoutinePose {
        let end=duration(miss:miss),release=peelRelease(miss:miss)
        let engagement=RoutineLibrary.smooth(t,0.08,0.45)*(1-RoutineLibrary.smooth(t,release+0.12,end-0.15))
        let peelStart=miss ? 1.36:0.98
        let peel=SIMD3<Float>(RoutineLibrary.smooth(t,peelStart,peelStart+0.16),RoutineLibrary.smooth(t,peelStart+0.05,peelStart+0.21),RoutineLibrary.smooth(t,peelStart+0.10,peelStart+0.26))
        let remaining:Float=miss ? 1:1-0.45*RoutineLibrary.smooth(t,2.14,2.34)-0.55*RoutineLibrary.smooth(t,4.32,4.52)
        let heldAngle=angle(at:min(t,release),miss:miss)
        var rotation=simd_quatf(angle:heldAngle,axis:[0,0,1])
        let wrist=base(at:min(t,release),miss:miss)-SIMD3<Float>(0,0.06,0)
        let handOpen=RoutineLibrary.smooth(t,release-0.04,release+0.10)
        var hands:[HandSide:HandIntent]=[.left:HandIntent(wrist:wrist,fingers:[0.8,0.2,0],palm:[0,0,1],openness:1,weight:engagement,grip:1-handOpen)]
        if !miss {
            let clear=RoutineLibrary.smooth(t,3.55,3.85)*(1-RoutineLibrary.smooth(t,4.75,5.05))
            hands[.right]=HandIntent(wrist:[0.34,-0.18,0.46],fingers:[-1,0,0.10],palm:[0,-0.20,-1],openness:0.75,weight:clear,grip:0.10)
        }
        if miss {
            let support=RoutineLibrary.smooth(t,3.15,3.55)*(1-RoutineLibrary.smooth(t,9.95,10.25))
            hands[.right]=HandIntent(wrist:[0.14,0.05,0.48],fingers:[-1,0.1,0],palm:[0,0,1],openness:0.25,weight:support)
        }
        let reveal=RoutineLibrary.smooth(t,0.55,0.73)
        let vanish=1-RoutineLibrary.smooth(t,release+0.48,min(end-0.15,release+0.85))
        var anchor:PropAnchor = .attachment(.wrist(.left))
        var offset=SIMD3<Float>(0,0.06,0)
        if t>=release {
            anchor = .character;offset=peelFlight(t,miss:miss)
            rotation=simd_quatf(angle:Float(t-release)*9,axis:normalize(SIMD3<Float>(0.7,0.2,1)))*rotation
        }
        var props:[PropCue]=[]
        if reveal*vanish>0 {
            props.append(PropCue(id:"banana.peel",kind:.bananaPeel,anchor:anchor,offset:offset,rotation:rotation,scale:SIMD3(repeating:size),visibility:reveal*vanish,deformation:.peel(openings:peel)))
        }
        var fruitAnchor:PropAnchor = .attachment(.wrist(.left)),fruitOffset=SIMD3<Float>(0,0.06,0)
        var fruitRotation=simd_quatf(angle:angle(at:t,miss:miss),axis:[0,0,1])
        var fruitVisibility=reveal*(miss ? 1:1-RoutineLibrary.smooth(t,4.40,4.53))
        if miss && t>=fruitRelease {
            fruitAnchor = .character;fruitOffset=fruitFlight(t)
            fruitRotation=simd_quatf(angle:-0.15-Float(t-fruitRelease)*2.5,axis:[0,0,1])
            fruitVisibility *= 1-RoutineLibrary.smooth(t,2.12,2.40)
        }
        if fruitVisibility>0 {
            props.append(PropCue(id:"banana.fruit",kind:.bananaFruit,anchor:fruitAnchor,offset:fruitOffset,rotation:fruitRotation,scale:SIMD3(repeating:size),visibility:fruitVisibility,deformation:.fruit(remaining:remaining)))
        }
        let chew:Float=miss ? 0:(0.07+0.07*sin(Float(t)*15))*(RoutineLibrary.smooth(t,2.35,2.55)*(1-RoutineLibrary.smooth(t,3.8,4.0))+RoutineLibrary.smooth(t,4.50,4.65)*(1-RoutineLibrary.smooth(t,5.1,5.3)))
        let jaw=(miss ? missedJaw:eatingJaw).sample(at:t)+chew
        let pitch=miss ? missedPitch.sample(at:t):-0.07*jaw
        let looking=miss ? missedLook.sample(at:t):0
        let eyelids:Float=miss ? 0:RoutineLibrary.smooth(t,4.20,4.30)*(1-RoutineLibrary.smooth(t,4.38,4.55))*0.75
        return RoutinePose(hands:hands,bodyYaw:-0.18*engagement,headYaw:-0.08*engagement+looking,headTilt:0.025*engagement,headPitch:pitch,face:FacialIntent(jawOpening:jaw,eyeClosure:eyelids,gaze:[-0.20*engagement+looking,miss ? -pitch*0.35:0],smileOffset:miss ? -0.20*RoutineLibrary.smooth(t,3.2,3.6)*(1-RoutineLibrary.smooth(t,10.5,end)):0),props:props)
    }
}
