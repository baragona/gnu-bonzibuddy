import simd

@main struct CheckHandOrientation {
    static func main() {
        let frames=[HandOrientation(fingers:[1,0,0],palm:[0,0,-1]),HandOrientation(fingers:[-1,0,0],palm:[0,0,1]),HandOrientation(fingers:[0,-1,0],palm:[1,0,0]),HandOrientation(fingers:[-1,0,0.1],palm:[0,-0.2,-1])]
        var maximum:Float=0,samples=0
        for a in frames {for b in frames {
            for step in 0...120 {
                let frame=a.blended(to:b,weight:Float(step)/120)
                maximum=max(maximum,abs(length(frame.fingers)-1),abs(length(frame.palm)-1),abs(dot(frame.fingers,frame.palm)))
                precondition(frame.rotation.vector.x.isFinite && length(cross(frame.fingers,frame.palm))>0.9999)
                if step==0 {precondition(length(frame.fingers-a.fingers)<0.00001 && length(frame.palm-a.palm)<0.00001)}
                if step==120 {precondition(length(frame.fingers-b.fingers)<0.00001 && length(frame.palm-b.palm)<0.00001)}
                samples+=1
            }
        }}
        precondition(maximum<0.00001)
        print("Passed \(samples) hand-frame samples; maximum orthonormal error \(maximum)")
    }
}
