import Foundation

@main struct CheckContinuousTrack {
    static func main() {
        let cases:[[(Double,Float)]]=[[(0,0.001),(0.1,0.035),(0.5,0.063),(1,0.162),(1.3,0.306),(1.5,0.514),(1.7,0.75),(1.9,1),(2.7,1)],[(0,0),(0.5,-1),(1,0.5),(2,0)],[(0,1),(0.2,1),(2,1)]]
        var samples=0,maximumDerivativeJump:Float=0
        for keys in cases {
            let track=ContinuousTrack(keys)
            for i in 1..<keys.count {
                let a=keys[i-1],b=keys[i]
                for frame in 0...100 {
                    let value=track.sample(at:a.0+(b.0-a.0)*Double(frame)/100)
                    precondition(value.isFinite && value>=min(a.1,b.1)-0.000001 && value<=max(a.1,b.1)+0.000001,"Curve overshoot")
                    samples+=1
                }
            }
            for key in keys {
                precondition(abs(track.sample(at:key.0)-key.1)<0.000001,"Missed authored key")
                let h=0.0001,center=track.sample(at:key.0)
                let left=(center-track.sample(at:key.0-h))/Float(h),right=(track.sample(at:key.0+h)-center)/Float(h)
                maximumDerivativeJump=max(maximumDerivativeJump,abs(left-right))
            }
        }
        precondition(maximumDerivativeJump<0.02,"Travel velocity jumps at a key")
        print("Passed \(samples) bounded samples; maximum finite-difference velocity jump \(maximumDerivativeJump)")
    }
}
