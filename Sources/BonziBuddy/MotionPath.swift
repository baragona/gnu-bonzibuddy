import simd

// A spatial path preserves velocity through authored waypoints. MotionTrack
// remains useful for deliberate pose holds; flight should not stop at every key.
struct MotionPath {
    let keys:[(Double,SIMD3<Float>)]
    private let velocities:[SIMD3<Float>]
    init(_ keys:[(Double,SIMD3<Float>)]) {
        precondition(keys.count>=2)
        for i in keys.indices {
            precondition(keys[i].0.isFinite && (0..<3).allSatisfy {keys[i].1[$0].isFinite})
            if i>0 {precondition(keys[i].0>keys[i-1].0)}
        }
        self.keys=keys
        velocities=keys.indices.map {i in
            if i==0 || i==keys.count-1 {return .zero}
            return (keys[i+1].1-keys[i-1].1)/Float(keys[i+1].0-keys[i-1].0)
        }
    }
    func sample(at time:Double)->SIMD3<Float> {
        if time<=keys[0].0 {return keys[0].1}
        if time>=keys.last!.0 {return keys.last!.1}
        let end=keys.firstIndex {$0.0>time}!,start=end-1
        let duration=Float(keys[end].0-keys[start].0),t=Float(time-keys[start].0)/duration,t2=t*t,t3=t2*t
        var point=keys[start].1*(2*t3-3*t2+1)
        point += velocities[start]*(duration*(t3-2*t2+t))
        point += keys[end].1*(-2*t3+3*t2)
        point += velocities[end]*(duration*(t3-t2))
        return point
    }
}
