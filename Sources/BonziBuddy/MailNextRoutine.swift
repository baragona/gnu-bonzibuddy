import simd

// Original MailNext is a 2.80-second pass from an already held letter. Add
// retrieval for standalone selection, a reading hold, and the shared return.
enum MailNextRoutine {
    static let duration=6.65
    static let holdRange=3.90..<5.65
    static let continuation=RoutineContinuation(family:.mail,entryElapsed:1.10,acceptsFrom:0..<5.65,delay:{max(0,2.05-$0)})
    static func sample(at t:Double)->RoutinePose {
        if t<1.10 {return MailReadRoutine.sample(at:t,flapOpening:0,flapGrip:0)}
        if t>=holdRange.lowerBound {return MailReadRoutine.sample(at:2.10+t-holdRange.lowerBound)}
        let local=t-1.10
        let opened=RoutineLibrary.smooth(local,0.10,0.30)*(1-RoutineLibrary.smooth(local,0.40,0.60))
        let grip=RoutineLibrary.smooth(local,0,0.10)*(1-RoutineLibrary.smooth(local,0.60,0.95))
        var pose=MailReadRoutine.sample(at:2.10,flapOpening:opened,flapGrip:grip)
        let reading=RoutineLibrary.smooth(t,1.10,1.35)
        pose.headPitch=0.08*reading
        let gaze=local<0.95 ? Float(0):0.20*sin(Float(local-0.95)*2*Float.pi/1.85)
        pose.face=FacialIntent(eyeClosure:0.12*reading,gaze:[gaze*reading,-0.60*reading])
        return pose
    }
}
