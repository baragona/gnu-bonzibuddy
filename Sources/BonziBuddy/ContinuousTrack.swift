import Foundation

// Shape-preserving cubic interpolation for continuous travel. Unlike a gesture
// track, passing through a key does not bring the actor to a full stop. Harmonic
// tangents prevent overshoot at extrema and keep positive scale keys positive.
struct ContinuousTrack {
    private let keys:[(Double,Float)]
    private let tangents:[Float]
    init(_ keys:[(Double,Float)]) {
        precondition(keys.count>=2 && keys.allSatisfy({$0.0.isFinite && $0.1.isFinite}))
        precondition(zip(keys,keys.dropFirst()).allSatisfy({$0.0.0<$0.1.0}))
        self.keys=keys
        let widths=zip(keys,keys.dropFirst()).map {Float($1.0-$0.0)}
        let slopes=zip(keys,keys.dropFirst()).enumerated().map {($0.element.1.1-$0.element.0.1)/widths[$0.offset]}
        var m=[Float](repeating:0,count:keys.count)
        for i in 1..<(keys.count-1) where slopes[i-1]*slopes[i]>0 {
            let a=2*widths[i]+widths[i-1],b=widths[i]+2*widths[i-1]
            m[i]=(a+b)/(a/slopes[i-1]+b/slopes[i])
        }
        tangents=m // Stationary endpoints join a held entry/exit without a snap.
    }
    func sample(at t:Double)->Float {
        if t<=keys[0].0 {return keys[0].1}
        for i in 1..<keys.count where t<=keys[i].0 {
            let a=keys[i-1],b=keys[i],width=Float(b.0-a.0),u=Float((t-a.0)/(b.0-a.0)),u2=u*u,u3=u2*u
            return (2*u3-3*u2+1)*a.1+(u3-2*u2+u)*width*tangents[i-1]+(-2*u3+3*u2)*b.1+(u3-u2)*width*tangents[i]
        }
        return keys.last!.1
    }
}
