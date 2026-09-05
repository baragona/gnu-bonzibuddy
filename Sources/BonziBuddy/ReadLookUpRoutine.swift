import simd

// Original ReadLookUp / Continued / Return storage timelines: 4.95 / 5.80 / 2.53s.
// Share the physical book retrieval and seated rig with Read; this performance
// owns its gaze and conversational gestures rather than replaying a page turn.
enum ReadLookUpRoutine {
    static let duration=13.28
    static let holdRange=4.95..<10.75
    private static let gestures=[6.15..<6.90,7.35..<8.05]
    static func returnDelay(at t:Double)->Double {
        for gesture in gestures where gesture.contains(t) {return gesture.upperBound-t}
        return 0
    }
    static func sample(at t:Double)->RoutinePose {
        let physicalTime:Double
        if t<2.40 {physicalTime=t}
        else if t<holdRange.upperBound {physicalTime=4.30}
        else {physicalTime=9.05+(t-holdRange.upperBound)*2.56/2.53}
        var pose=ReadRoutine.sample(at:physicalTime)
        let reading=RoutineLibrary.smooth(t,2.10,2.40)*(1-RoutineLibrary.smooth(t,10.85,11.10))
        let loop=t-holdRange.lowerBound
        // Finish entry and each loop looking at the viewer. The next loop
        // starts with a deliberate glance down to the book.
        let down:Float
        if t<holdRange.lowerBound {
            down=1-RoutineLibrary.smooth(t,4.55,4.85)
        } else if t<holdRange.upperBound {
            down=RoutineLibrary.smooth(loop,0,0.30)*(1-RoutineLibrary.smooth(loop,1.20,1.40))
                + RoutineLibrary.smooth(loop,3.05,3.35)*(1-RoutineLibrary.smooth(loop,5.40,5.70))
        } else {down=0}
        let scan=Float(sin((t-2.4)*2.8))*0.28*down
        pose.headPitch=0.14*down*reading
        pose.face=FacialIntent(eyeClosure:0.18*down*reading,gaze:[scan*reading,-0.85*down*reading],smileOffset:0.06*(1-down)*reading)
        var gesture:Float=0
        for interval in gestures {
            gesture=max(gesture,RoutineLibrary.smooth(t,interval.lowerBound,interval.lowerBound+0.20)*(1-RoutineLibrary.smooth(t,interval.upperBound-0.20,interval.upperBound)))
        }
        if var hand=pose.hands[.left],gesture>0 {
            hand.wrist += (SIMD3<Float>(-0.43,0.08,0.44)-hand.wrist)*gesture
            let rotation=simd_quatf(angle:-0.35*gesture,axis:[0,0,1])
            let roll=simd_quatf(angle:Float.pi*gesture,axis:simd_normalize(hand.fingers))
            hand.palm=rotation.act(roll.act(hand.palm))
            hand.fingers=rotation.act(hand.fingers)
            hand.grip *= 1-gesture
            pose.hands[.left]=hand
        }
        return pose
    }
}
