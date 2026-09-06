import Foundation
import simd

// Distances use character model units; rotations use radians; time uses seconds.
// Choreography describes intent in character space. FanRig solves limbs; PropRenderer
// resolves attachment frames after skinning. Neither needs to know the other's geometry.
enum HandTargetSpace {case character, torso}
struct HandIntent {
    var wrist: SIMD3<Float>
    var fingers: SIMD3<Float>
    var palm: SIMD3<Float>
    var targetSpace:HandTargetSpace = .character
    var openness: Float = 1
    var weight: Float = 1
    var pointing: Bool = false
    var grip: Float = 0
    var fist: Float = 0
    var fingersTogether: Float = 0
    var thumbFold: Float = 0
    var palmContact: SIMD3<Float>? = nil // Surface target; rig resolves wrist from its anatomy.
    var shoulderOffset=SIMD3<Float>.zero
    var elbowBend: SIMD3<Float>? = nil // Preferred bend direction in character space.
    var indexTipContact: SIMD3<Float>? = nil // Straight index only; resolved using the imported hand frame.
}
struct RoutinePose {
    var actorPlacement=ActorPlacement()
    var hands: [HandSide:HandIntent] = [:] // Semantic sides, resolved by the rig.
    var bodyYaw: Float = 0
    var torsoTilt: Float = 0
    var headYaw: Float = 0
    var headTilt: Float = 0
    var headPitch: Float = 0
    var face=FacialIntent()
    var props: [PropCue] = []
    var stance=StanceIntent()
}
enum RoutineLibrary {
    // A short clearance gesture for the free hand while the opposite hand
    // carries a wide prop across the chest. Timing belongs to each routine.
    static func handAside(_ side:HandSide,weight:Float)->HandIntent {
        HandIntent(wrist:[side.sign*0.58,-0.15,0.30],fingers:[side.sign*0.15,-1,0.10],palm:[0,0,1],openness:0.8,weight:weight,grip:0.15)
    }

    static func handOnBelly(_ side:HandSide,weight:Float)->HandIntent {
        HandIntent(wrist:[side.sign*0.34,-0.18,0.46],fingers:[-side.sign,0,0.10],palm:[0,-0.20,-1],openness:0.75,weight:weight,grip:0.10)
    }
    static func smooth(_ t: Double, _ start: Double, _ end: Double) -> Float {
        let x=Float(min(1,max(0,(t-start)/(end-start))))
        return x*x*x*(x*(x*6-15)+10)
    }
    static let definitions:[Action:RoutineDefinition]=[
        .vineEntrance:RoutineDefinition(duration:VineEntranceRoutine.duration,changesFacing:true,changesStance:true,entryPose:.authored,handoffPolicy:.finishRoutine,sample:VineEntranceRoutine.sample),
        .hug:RoutineDefinition(duration:HugRoutine.duration,changesStance:true,sample:HugRoutine.sample),
        .giggle:RoutineDefinition(duration:GiggleRoutine.duration,changesStance:true,sample:GiggleRoutine.sample),
        .blowKiss:RoutineDefinition(duration:BlowKissRoutine.duration,sample:BlowKissRoutine.sample),
        .wink:RoutineDefinition(duration:WinkRoutine.duration,sample:WinkRoutine.sample),
        .shush:RoutineDefinition(duration:ShushRoutine.duration,sample:ShushRoutine.sample),
        .chestBeat:RoutineDefinition(duration:ChestBeatRoutine.duration,changesStance:true,sample:ChestBeatRoutine.sample),
        .mailFull:RoutineDefinition(duration:MailFullRoutine.duration,changesFacing:true,holdRange:MailFullRoutine.holdRange,handoffPolicy:.finishRoutine,continuation:MailFullRoutine.continuation,sample:MailFullRoutine.sample),
        .mailNext:RoutineDefinition(duration:MailNextRoutine.duration,holdRange:MailNextRoutine.holdRange,handoffPolicy:.finishRoutine,continuation:MailNextRoutine.continuation,sample:MailNextRoutine.sample),
        .mailRead:RoutineDefinition(duration:MailReadRoutine.duration,holdRange:MailReadRoutine.holdRange,handoffPolicy:.finishRoutine,continuation:MailReadRoutine.continuation,sample:MailReadRoutine.sample),
        .mailEmpty:RoutineDefinition(duration:MailEmptyRoutine.duration,changesStance:true,handoffPolicy:.finishRoutine,sample:MailEmptyRoutine.sample),
        .writeOnce:WriteSingleRoutine.once,
        .writeAgain:WriteSingleRoutine.again,
        .writePause:RoutineDefinition(duration:WritePauseRoutine.duration,changesFacing:true,holdRange:WritePauseRoutine.holdRange,handoffPolicy:.finishRoutine,continuation:WritePauseRoutine.continuation,sample:WritePauseRoutine.sample),
        .write:RoutineDefinition(duration:WriteRoutine.duration,changesFacing:true,holdRange:WriteRoutine.holdRange,handoffPolicy:.finishRoutine,returnDelay:WriteRoutine.returnDelay,continuation:WriteRoutine.continuation,sample:WriteRoutine.sample),
        .readLookUp:RoutineDefinition(duration:ReadLookUpRoutine.duration,changesStance:true,holdRange:ReadLookUpRoutine.holdRange,handoffPolicy:.finishRoutine,returnDelay:ReadLookUpRoutine.returnDelay,sample:ReadLookUpRoutine.sample),
        .read:RoutineDefinition(duration:ReadRoutine.duration,changesStance:true,holdRange:ReadRoutine.holdRange,handoffPolicy:.finishRoutine,returnDelay:{t in t>=5.65 && t<7.20 ? 7.20-t:0},sample:ReadRoutine.sample),
        .butterfly:RoutineDefinition(duration:ButterflyRoutine.duration,changesFacing:true,handoffPolicy:.finishRoutine,sample:ButterflyRoutine.sample),
        .headphones:RoutineDefinition(duration:HeadphonesRoutine.duration,holdRange:HeadphonesRoutine.holdRange,handoffPolicy:.finishRoutine,sample:HeadphonesRoutine.sample),
        .sunglasses:RoutineDefinition(duration:SunglassesRoutine.duration,holdRange:SunglassesRoutine.holdRange,sample:SunglassesRoutine.sample),
        .globe:RoutineDefinition(duration:GlobeRoutine.duration,changesFacing:true,handoffPolicy:.finishRoutine,sample:GlobeRoutine.sample),
        .juggle:RoutineDefinition(duration:CoconutJuggle.duration,handoffPolicy:.finishRoutine,sample:CoconutJuggle.sample),
        .banana:RoutineDefinition(duration:BananaRoutine.duration(miss:false),changesFacing:true,handoffPolicy:.finishRoutine,sample:{BananaRoutine.sample(at:$0,miss:false)}),
        .bananaMiss:RoutineDefinition(duration:BananaRoutine.duration(miss:true),changesFacing:true,handoffPolicy:.finishRoutine,sample:{BananaRoutine.sample(at:$0,miss:true)})
    ]
    static func sample(_ action:Action,at t:Double)->RoutinePose {
        guard let definition=definitions[action],t>=0,t<=definition.duration else {return RoutinePose()}
        return definition.sample(t)
    }
}

// One definition owns each routine's timing, movement policy, and pure sampler.
// The action catalog, rig, face system, and validators share this definition.
enum RoutineEntryPose {case rest,authored}
enum RoutineHandoffPolicy {case interruptible, finishRoutine}
enum RoutineFamily {case writing,mail}
struct RoutineContinuation {
    let family:RoutineFamily
    let entryElapsed:Double
    let acceptsFrom:Range<Double>
    let delay:(Double)->Double
    var exitElapsed:(Double)->Double? = {_ in nil}
}
struct RoutineDefinition {
    let duration:Double
    var changesFacing=false
    var changesStance=false
    var entryPose:RoutineEntryPose = .rest
    var holdRange:Range<Double>?
    var handoffPolicy:RoutineHandoffPolicy = .interruptible
    var returnDelay:(Double)->Double = {_ in 0}
    var continuation:RoutineContinuation?
    let sample:(Double)->RoutinePose
}
