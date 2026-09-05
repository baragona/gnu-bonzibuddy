import simd

// Immutable authored keys, validated once when the track is constructed.
// Sampling allocates no key arrays and stays bounded between adjacent values.
struct MotionTrack<Value> {
    private let keys:[(Double,Value)]
    private let interpolate:(Value,Value,Float)->Value
    private init(keys:[(Double,Value)],interpolate:@escaping (Value,Value,Float)->Value) {
        precondition(!keys.isEmpty && keys.allSatisfy({$0.0.isFinite}),"A track needs finite key times")
        precondition(zip(keys,keys.dropFirst()).allSatisfy({$0.0.0<$0.1.0}),"Track times must increase")
        self.keys=keys;self.interpolate=interpolate
    }
    func sample(at t:Double)->Value {
        if t<=keys[0].0 {return keys[0].1}
        for i in 1..<keys.count where t<=keys[i].0 {
            let a=keys[i-1],b=keys[i]
            return interpolate(a.1,b.1,RoutineLibrary.smooth(t,a.0,b.0))
        }
        return keys.last!.1
    }
}
extension MotionTrack where Value == Float {
    init(_ keys:[(Double,Float)]) {self.init(keys:keys,interpolate:{$0+($1-$0)*$2})}
}
extension MotionTrack where Value == SIMD3<Float> {
    init(_ keys:[(Double,SIMD3<Float>)]) {self.init(keys:keys,interpolate:{$0+($1-$0)*$2})}
}
