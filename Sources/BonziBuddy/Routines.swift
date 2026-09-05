import Foundation
import simd

// Choreography describes intent in character space. FanRig solves limbs; PropRenderer
// resolves attachment frames after skinning. Neither needs to know the other's geometry.
struct HandIntent {
    var wrist: SIMD3<Float>
    var fingers: SIMD3<Float>
    var palm: SIMD3<Float>
    var openness: Float = 1
    var weight: Float = 1
    var pointing: Bool = false
}
enum PropKind: Int { case globe }
enum PropAnchor { case character; case joint(Int) }
struct PropCue {
    var id: String
    var kind: PropKind
    var anchor: PropAnchor
    var offset: SIMD3<Float>
    var rotation: simd_quatf = simd_quatf(angle:0,axis:[0,1,0])
    var scale: SIMD3<Float> = SIMD3(repeating:1)
    var visibility: Float = 1
}
struct RoutinePose {
    var hands: [Int:HandIntent] = [:] // Source wrist joints 26 and 42.
    var bodyYaw: Float = 0
    var headYaw: Float = 0
    var headTilt: Float = 0
    var gaze = SIMD2<Float>.zero
    var props: [PropCue] = []
}
enum RoutineLibrary {
    static func smooth(_ t: Double, _ start: Double, _ end: Double) -> Float {
        let x=Float(min(1,max(0,(t-start)/(end-start))))
        return x*x*x*(x*(x*6-15)+10)
    }
    static func sample(_ action:Action, at t:Double) -> RoutinePose {
        guard action == .globe else { return RoutinePose() }
        // Search: raise, reveal, spin while following the globe, lower and stow.
        // Authored continuous poses follow the extracted Search/SearchingReturn beats.
        let weight=smooth(t,0,0.75)*(1-smooth(t,5.4,6.2))
        let reveal=smooth(t,0.55,0.85)*(1-smooth(t,5.25,5.55))
        let left=HandIntent(wrist:[-0.88,0.32,0.32],fingers:[-0.15,1,0],palm:[0,0,1],weight:weight,pointing:true)
        let right=HandIntent(wrist:[-0.33,0.25,0.46],fingers:[-0.8,0.45,0],palm:[0,0,1],openness:0.65,weight:weight,pointing:true)
        let spin=Float(max(0,t-0.85))*2.8*smooth(t,0.85,1.2)
        let globe=PropCue(id:"search.globe",kind:.globe,anchor:.joint(26),offset:[-0.025,0.50,0],rotation:simd_quatf(angle:spin,axis:[0,1,0]),scale:SIMD3(repeating:0.35),visibility:reveal)
        return RoutinePose(hands:[26:left,42:right],bodyYaw:-0.65*weight,headYaw:-0.10*weight,headTilt:0.04*weight,gaze:[-0.40*weight,0.15*weight],props:reveal>0 ? [globe]:[])
    }
}
