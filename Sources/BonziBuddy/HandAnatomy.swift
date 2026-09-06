import simd

// Calibration belongs to the character, not to each prop routine. Directions
// describe an orthonormal hand frame; the contact is on the palm surface.
struct HandAnatomy {
    var palmCenterAlongFingers:Float
    var palmSurfaceDepth:Float
    var indexTipInHandFrame:SIMD3<Float>
    func surfaceOffset(fingers:SIMD3<Float>,palm:SIMD3<Float>)->SIMD3<Float> {
        let forward=normalize(fingers)
        let normal=normalize(palm-forward*dot(palm,forward))
        return forward*palmCenterAlongFingers+normal*palmSurfaceDepth
    }
    func resolve(_ intent:HandIntent)->HandIntent {
        var result=intent
        if let tip=intent.indexTipContact {
            let f=normalize(intent.fingers),p=normalize(intent.palm-f*dot(intent.palm,f))
            result.wrist=tip-(f*indexTipInHandFrame.x+p*indexTipInHandFrame.y+cross(f,p)*indexTipInHandFrame.z)
            return result
        }
        guard let contact=intent.palmContact else {return intent}
        result.wrist=contact-surfaceOffset(fingers:intent.fingers,palm:intent.palm)
        return result
    }
}

extension FanRig {
    func handAnatomy(_ side:HandSide)->HandAnatomy {
        let wrist=side == .left ? 26:42,knuckle=side == .left ? 30:46
        let span=length(rest[knuckle].columns.3-rest[wrist].columns.3)
        // Fan mesh calibration: palm contact lies inside the knuckle row.
        let index=side == .left ? 29:45
        let tip=rest[index].columns.3+(rest[index].columns.3-rest[index-1].columns.3)*0.18-rest[wrist].columns.3
        let delta=SIMD3(tip.x,tip.y,tip.z)
        let finger=rest[knuckle].columns.3-rest[wrist].columns.3
        let f=normalize(SIMD3(finger.x,finger.y,finger.z)),p=normalize(SIMD3<Float>(0,-1,0)-f*dot(SIMD3<Float>(0,-1,0),f))
        return HandAnatomy(palmCenterAlongFingers:span*0.65,palmSurfaceDepth:0.055,indexTipInHandFrame:[dot(delta,f),dot(delta,p),dot(delta,cross(f,p))])
    }
}
