import simd

// Whole-character stage motion is applied after articulation, so aerial travel
// does not make grounded leg IK stretch toward the floor. Scale stays positive;
// persistent hidden/shown state belongs to playback, not a singular transform.
struct ActorPlacement {
    var offset=SIMD3<Float>.zero
    var rotation=simd_quatf(angle:0,axis:SIMD3<Float>(0,1,0))
    var scale:Float=1
    var isValid:Bool {
        (0..<3).allSatisfy({offset[$0].isFinite}) && scale.isFinite && scale>=0.001 && abs(length(rotation.vector)-1)<0.001
    }
    var matrix:simd_float4x4 {
        translation(offset)*simd_float4x4(rotation)*simd_float4x4(diagonal:SIMD4(SIMD3<Float>(repeating:scale),1))
    }
}
