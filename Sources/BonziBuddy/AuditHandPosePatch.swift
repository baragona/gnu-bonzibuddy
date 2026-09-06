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
        let data=try Data(contentsOf:URL(fileURLWithPath:path))
        let fields:Set<String>=["palmContact","shoulderOffset","elbowBend","fingers","palm","grip","thumbFold"]
        guard let object=try JSONSerialization.jsonObject(with:data) as? [String:Any] else {throw failure("Pose-study patch must be an object")}
        for (side,value) in object {
            guard let values=value as? [String:Any],Set(values.keys).isSubset(of:fields),!values.values.contains(where:{$0 is NSNull}) else {
                throw failure("Unknown or null pose-study field for \(side)")
            }
        }
        let patches=try JSONDecoder().decode([String:AuditHandPosePatch].self,from:data)
        guard patches.keys.allSatisfy({HandSide(rawValue:$0) != nil}) else {throw failure("Unknown pose-study hand side")}
        for patch in patches.values {
            guard (patch.fingers == nil) == (patch.palm == nil) else {throw failure("Pose-study fingers and palm must be supplied together")}
            if let fingers=patch.fingers,let palm=patch.palm {
                guard length(cross(normalize(fingers),normalize(palm)))>0.001 else {throw failure("Collinear pose-study hand frame")}
            }
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
                pose.hands[side]=hand
            }
        }
    }
}
