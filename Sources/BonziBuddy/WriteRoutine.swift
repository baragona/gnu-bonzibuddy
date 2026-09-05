import simd

// Original Write (4.30), WriteContinued (1.20), WriteReturn (1.45).
enum WriteRoutine {
    static let duration=6.95
    static let holdRange=4.30..<5.50
    static let center=MotionTrack<SIMD3<Float>>([(0,[0.58,-0.40,-0.22]),(0.65,[0.58,-0.40,-0.22]),(1.0,[0.60,-0.40,0.25]),(1.35,[0.22,-0.12,0.47]),(5.50,[0.22,-0.12,0.47]),(5.95,[0.60,-0.40,0.25]),(6.35,[0.58,-0.40,-0.22]),(6.95,[0.58,-0.40,-0.22])])
    static func returnDelay(at t:Double)->Double {
        guard t>=1.90 && t<5.50 else {return 0}
        let phase=(t-1.90).truncatingRemainder(dividingBy:1.20)
        return phase>0.12 && phase<1.10 ? 1.20-phase:0
    }
    static func sample(at t:Double)->RoutinePose {
        let active=RoutineLibrary.smooth(t,0.1,0.55)*(1-RoutineLibrary.smooth(t,6.45,6.95))
        let working=RoutineLibrary.smooth(t,1.20,1.55)*(1-RoutineLibrary.smooth(t,5.50,5.85))
        let tilt=simd_quatf(angle:-2.15*working,axis:[1,0,0])*simd_quatf(angle:0.18*working,axis:[0,0,1])
        let origin=center.sample(at:t)
        let anchor=PropAnchor.transformed(.character,offset:origin,rotation:tilt)
        let visible=RoutineLibrary.smooth(t,0.55,0.75)*(1-RoutineLibrary.smooth(t,6.15,6.40))
        let cycle=t<4.30 ? max(0,t-1.90).truncatingRemainder(dividingBy:1.20):t-4.30
        let writing=RoutineLibrary.smooth(cycle,0.12,0.25)*(1-RoutineLibrary.smooth(cycle,0.92,1.10))*working
        let stroke=Float(cycle)
        let contact=SIMD3<Float>(-0.14+0.19*RoutineLibrary.smooth(cycle,0.25,0.92)*writing,-0.04+0.025*sin(stroke*40)*writing,WritingGeometry.paperZ+0.002)
        let tip=origin+tilt.act(contact)+SIMD3<Float>(-0.05,0.19,0)*(1-writing)*working
        let pencilRotation=simd_quatf(from:SIMD3<Float>(0,1,0),to:normalize(SIMD3<Float>(-0.38,0.90,0.15)))
        let right=HandIntent(wrist:origin+tilt.act([0.39,-0.08,-0.10]),fingers:tilt.act([-1,0,0]),palm:tilt.act([0,0,1]),weight:active,grip:0.15)
        let left=HandIntent(wrist:tip+pencilRotation.act([0,0.19,0])+SIMD3<Float>(-0.12,-0.06,0.04),fingers:[0.9,0.35,-0.2],palm:[0,-0.3,-1],weight:active,grip:0.78)
        let props=visible>0 ? [PropCue(id:"write.pad",kind:.writingPad,anchor:anchor,offset:.zero,visibility:visible),PropCue(id:"write.pencil",kind:.pencil,anchor:.character,offset:tip,rotation:pencilRotation,visibility:visible)]:[]
        return RoutinePose(hands:[.left:left,.right:right],bodyYaw:0.40*working,headPitch:0.10*writing,face:FacialIntent(eyeClosure:0.12*writing,gaze:[0.25*working,-0.65*writing]),props:props)
    }
}
