import simd

// Calibration belongs to the character, not to each prop routine. Directions
// describe an orthonormal hand frame; the contact is on the palm surface.
struct HandAnatomy {
    var palmCenterAlongFingers:Float
    var palmSurfaceDepth:Float
    func surfaceOffset(fingers:SIMD3<Float>,palm:SIMD3<Float>)->SIMD3<Float> {
        let forward=normalize(fingers)
        let normal=normalize(palm-forward*dot(palm,forward))
        return forward*palmCenterAlongFingers+normal*palmSurfaceDepth
    }
    func resolve(_ intent:HandIntent)->HandIntent {
        guard let contact=intent.palmContact else {return intent}
        var result=intent
        result.wrist=contact-surfaceOffset(fingers:intent.fingers,palm:intent.palm)
        return result
    }
}

extension FanRig {
    func handAnatomy(_ side:HandSide)->HandAnatomy {
        let wrist=side == .left ? 26:42,knuckle=side == .left ? 30:46
        let span=length(rest[knuckle].columns.3-rest[wrist].columns.3)
        // Fan mesh calibration: palm contact lies inside the knuckle row.
        return HandAnatomy(palmCenterAlongFingers:span*0.65,palmSurfaceDepth:0.055)
    }
}
