import simd

enum FootSide:CaseIterable {
    case left,right
    var sign:Float {self == .left ? -1:1}
}
struct FootIntent {
    var ankle:SIMD3<Float>
    var rotation:simd_quatf
    var kneeBend:SIMD3<Float>
    var weight:Float
}
// Character-space targets. The rig owns hip/knee/ankle indices and solves legs;
// a routine can sit, crouch, or step without embedding skeleton knowledge.
struct StanceIntent {
    var pelvisOffset=SIMD3<Float>.zero
    var feet:[FootSide:FootIntent]=[:]
}
