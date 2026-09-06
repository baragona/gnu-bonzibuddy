import simd

// A palm normal and finger direction define a rigid hand frame. Interpolating
// its rotation keeps them perpendicular while a hand reaches, grips or releases.
// Callers supply finite, nonzero, non-collinear directions (routine contract).
struct HandOrientation {
    let rotation:simd_quatf
    init(fingers:SIMD3<Float>,palm:SIMD3<Float>) {
        let f=normalize(fingers),p=normalize(palm-f*dot(palm,f))
        rotation=simd_quatf(simd_float3x3(columns:(f,p,cross(f,p))))
    }
    private init(rotation:simd_quatf) {self.rotation=rotation}
    var fingers:SIMD3<Float> {rotation.act([1,0,0])}
    var palm:SIMD3<Float> {rotation.act([0,1,0])}
    func blended(to other:HandOrientation,weight:Float)->HandOrientation {
        HandOrientation(rotation:simd_slerp(rotation,other.rotation,min(1,max(0,weight))))
    }
}
