import Foundation
import simd

// Read only by the geometry-audit command. Lets pose studies reuse the real
// skinning/crossing scan without rebuilding the app for each candidate.
struct AuditHandPosePatch:Decodable {
    var palmContact:SIMD3<Float>?
    var shoulderOffset:SIMD3<Float>?
    var elbowBend:SIMD3<Float>?
    var fingers:SIMD3<Float>?
    var palm:SIMD3<Float>?
    var grip:Float?
    var thumbFold:Float?

    static func load(_ path:String) throws -> ((inout RoutinePose)->Void) {
        let patches=try JSONDecoder().decode([String:AuditHandPosePatch].self,from:Data(contentsOf:URL(fileURLWithPath:path)))
        guard patches.keys.allSatisfy({HandSide(rawValue:$0) != nil}) else {throw failure("Unknown pose-study hand side")}
        for patch in patches.values {
            for vector in [patch.palmContact,patch.shoulderOffset,patch.elbowBend,patch.fingers,patch.palm].compactMap({$0}) {
                guard (0..<3).allSatisfy({vector[$0].isFinite}) else {throw failure("Nonfinite pose-study vector")}
            }
            for value in [patch.grip,patch.thumbFold].compactMap({$0}) {
                guard value.isFinite,(0...1).contains(value) else {throw failure("Invalid pose-study grip")}
            }
            for direction in [patch.elbowBend,patch.fingers,patch.palm].compactMap({$0}) {
                guard length(direction)>0.001 else {throw failure("Zero pose-study direction")}
            }
        }
        return {pose in
            for (name,patch) in patches {
                let side=HandSide(rawValue:name)!
                guard var hand=pose.hands[side] else {continue}
                if let v=patch.palmContact {hand.palmContact=v;hand.indexTipContact=nil}
                if let v=patch.shoulderOffset {hand.shoulderOffset=v}
                if let v=patch.elbowBend {hand.elbowBend=v}
                if let v=patch.fingers {hand.fingers=v}
                if let v=patch.palm {hand.palm=v}
                if let v=patch.grip {hand.grip=v}
                if let v=patch.thumbFold {hand.thumbFold=v}
                precondition(length(cross(hand.fingers,hand.palm))>0.001,"Collinear pose-study hand frame")
                pose.hands[side]=hand
            }
        }
    }
}
