import Foundation
import simd

// Distances use character model units; rotations use radians; time uses seconds.
// Choreography describes intent in character space. FanRig solves limbs; PropRenderer
// resolves attachment frames after skinning. Neither needs to know the other's geometry.
struct HandIntent {
    var wrist: SIMD3<Float>
    var fingers: SIMD3<Float>
    var palm: SIMD3<Float>
    var openness: Float = 1
    var weight: Float = 1
    var pointing: Bool = false
    var grip: Float = 0
}
struct RoutinePose {
    var hands: [HandSide:HandIntent] = [:] // Semantic sides, resolved by the rig.
    var bodyYaw: Float = 0
    var headYaw: Float = 0
    var headTilt: Float = 0
    var headPitch: Float = 0
    var face=FacialIntent()
    var props: [PropCue] = []
}
enum RoutineLibrary {
    static func smooth(_ t: Double, _ start: Double, _ end: Double) -> Float {
        let x=Float(min(1,max(0,(t-start)/(end-start))))
        return x*x*x*(x*(x*6-15)+10)
    }
    static let definitions:[Action:RoutineDefinition]=[
        .butterfly:RoutineDefinition(duration:ButterflyRoutine.duration,changesFacing:true,accessoryTransferPolicy:.finishRoutine,sample:ButterflyRoutine.sample),
        .headphones:RoutineDefinition(duration:HeadphonesRoutine.duration,holdRange:HeadphonesRoutine.holdRange,accessoryTransferPolicy:.finishRoutine,sample:HeadphonesRoutine.sample),
        .sunglasses:RoutineDefinition(duration:SunglassesRoutine.duration,holdRange:SunglassesRoutine.holdRange,sample:SunglassesRoutine.sample),
        .globe:RoutineDefinition(duration:GlobeRoutine.duration,changesFacing:true,accessoryTransferPolicy:.finishRoutine,sample:GlobeRoutine.sample),
        .juggle:RoutineDefinition(duration:CoconutJuggle.duration,accessoryTransferPolicy:.finishRoutine,sample:CoconutJuggle.sample),
        .banana:RoutineDefinition(duration:BananaRoutine.duration(miss:false),changesFacing:true,accessoryTransferPolicy:.finishRoutine,sample:{BananaRoutine.sample(at:$0,miss:false)}),
        .bananaMiss:RoutineDefinition(duration:BananaRoutine.duration(miss:true),changesFacing:true,accessoryTransferPolicy:.finishRoutine,sample:{BananaRoutine.sample(at:$0,miss:true)})
    ]
    static func sample(_ action:Action,at t:Double)->RoutinePose {
        guard let definition=definitions[action],t>=0,t<=definition.duration else {return RoutinePose()}
        return definition.sample(t)
    }
}

// One definition owns each routine's timing, movement policy, and pure sampler.
// The action catalog, rig, face system, and validators share this definition.
enum AccessoryTransferPolicy {case pauseAndResume, finishRoutine}
struct RoutineDefinition {
    let duration:Double
    var changesFacing=false
    var holdRange:Range<Double>?
    var accessoryTransferPolicy:AccessoryTransferPolicy = .pauseAndResume
    let sample:(Double)->RoutinePose
}
