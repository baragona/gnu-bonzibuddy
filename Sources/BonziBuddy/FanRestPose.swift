import simd

// Shared anatomical rest pose. Keep entrances, exits, and idle on the same
// frames; individual routines blend away from this calibration.
enum FanRestPose {
    static func upperArm(_ side:Float)->SIMD3<Float> {[side*0.78,-0.62,0.10]}
    static func forearm(_ side:Float)->SIMD3<Float> {[-side*1.05,side<0 ? 0.75:0.30,side<0 ? 1.20:0.95]}
    static func fingers(_ side:Float)->SIMD3<Float> {[-side,side<0 ? -0.08:0.08,side<0 ? 0.65:0.35]}
    static let palm=SIMD3<Float>(0,-0.35,-1)
    static let fingerCurl:[Float]=[0.20,0.45,0.20]
}
