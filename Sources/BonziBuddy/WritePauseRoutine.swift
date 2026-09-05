import simd

// The source WritePause lifts the pencil and looks back at the viewer. The
// writing stroke's final lift supplies that transition before the shared seam.
enum WritePauseRoutine {
    static let duration=4.85
    static let holdRange=2.40..<2.90
    static let continuation=RoutineContinuation(family:.writing,entryElapsed:1.90,acceptsFrom:0..<3.40,delay:{t in
        t<1.90 ? 1.90-t:t<2.90 ? min(0.50,t-1.90):max(0,3.40-t)
    },exitElapsed:{t in t<1.90 || t>=3.40 ? nil:t<2.90 ? max(2.90,5.30-t):t})
    static func sample(at t:Double)->RoutinePose {
        let physicalTime=t<1.90 ? t:t<3.40 ? 4.30:5.50+(t-3.40)
        var pose=WriteRoutine.sample(at:physicalTime)
        let attention=RoutineLibrary.smooth(t,1.90,2.40)*(1-RoutineLibrary.smooth(t,2.90,3.40))
        pose.headYaw = -0.40*attention
        pose.face.gaze.x *= 1-attention
        let lower=SIMD3<Float>(-0.32,-0.12,0)*attention
        pose.hands[.left]?.wrist += lower
        if let pencil=pose.props.firstIndex(where:{$0.kind == .pencil}) {pose.props[pencil].offset += lower}
        return pose
    }
}
