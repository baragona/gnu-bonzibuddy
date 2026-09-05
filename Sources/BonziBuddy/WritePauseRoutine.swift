import simd

// The source WritePause lifts the pencil and looks back at the viewer. The
// writing stroke's final lift supplies that transition before the shared seam.
enum WritePauseRoutine {
    static let duration=4.35
    static let holdRange=2.40..<2.90
    static let continuation=RoutineContinuation(family:.writing,entryElapsed:1.90,acceptsFrom:0..<2.90,delay:{max(0,1.90-$0)})
    static func sample(at t:Double)->RoutinePose {
        let physicalTime=t<1.90 ? t:t<2.90 ? 4.30:5.50+(t-2.90)
        var pose=WriteRoutine.sample(at:physicalTime)
        let attention=RoutineLibrary.smooth(t,1.90,2.40)*(1-RoutineLibrary.smooth(t,2.90,3.25))
        pose.headYaw = -0.40*attention
        pose.face.gaze.x *= 1-attention
        return pose
    }
}
