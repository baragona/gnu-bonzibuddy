import simd

// Choreography uses semantic body parts. Imported skeleton indices belong to FanRig.
enum HandSide: String, CaseIterable {
    case left, right
    init(sign:Float) {self=sign<0 ? .left:.right}
    var sign:Float {self == .left ? -1:1}
}
enum RigAttachment {case wrist(HandSide), indexTip(HandSide), head}
enum AttachmentAxes {case character, joint}

extension FanRig {
    func attachmentFrame(_ attachment:RigAttachment,axes:AttachmentAxes,bones:[Instance])->simd_float4x4 {
        let joint:Int
        switch attachment {
        case let .wrist(side): joint=side == .left ? 26:42
        case let .indexTip(side): joint=side == .left ? 29:45
        case .head: joint=56
        }
        var restPoint=rest[joint].columns.3
        if case .indexTip=attachment {
            // Distal fan-mesh samples extend ~0.0185 beyond a 0.1039 terminal segment.
            restPoint += (rest[joint].columns.3-rest[joint-1].columns.3)*0.18
        }
        let origin=bones[joint].model*restPoint
        var frame=bones[0].model
        if axes == .joint {
            // Remove scale/shear from the skin transform: a held rigid object
            // rotates with the body part without inheriting limb stretch.
            let m=bones[joint].model
            var r=simd_float3x3(columns:(SIMD3(m.columns.0.x,m.columns.0.y,m.columns.0.z),SIMD3(m.columns.1.x,m.columns.1.y,m.columns.1.z),SIMD3(m.columns.2.x,m.columns.2.y,m.columns.2.z)))
            r *= 1/max(length(r.columns.0),max(length(r.columns.1),length(r.columns.2)))
            for _ in 0..<6 {r=(r+r.inverse.transpose)*0.5}
            r *= actorScale // Preserve whole-actor scale while removing limb stretch.
            frame=simd_float4x4(columns:(SIMD4(r.columns.0,0),SIMD4(r.columns.1,0),SIMD4(r.columns.2,0),SIMD4(0,0,0,1)))
        }
        frame.columns.3=origin
        return frame
    }
}
