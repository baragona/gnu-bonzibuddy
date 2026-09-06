import simd

// Fan-eye UV calibration. Each row maps a change in horizontal surface-normal
// angle to the pupil offset used by the shader, preserving the approved neutral
// pupil placement. Eyes have different UV slopes; one shared offset drifts.
// Calibrated at pupil center V, including the rig's 1.13 horizontal head scale.
enum FanGazeCompensation {
    private static let positive:[SIMD2<Float>]=[
        [0,0],[0.951388,0.704654],[1.864965,1.090100],
        [2.813174,1.428596],[3.365407,1.689114],[3.737618,1.871708]
    ]
    static func offsets(for yaw:Float)->SIMD2<Float> {
        let index=min(5,abs(yaw)*10),lower=min(4,Int(index))
        let offset=positive[lower]+(positive[lower+1]-positive[lower])*(index-Float(lower))
        return yaw>=0 ? offset : -SIMD2(offset.y,offset.x)
    }
}
