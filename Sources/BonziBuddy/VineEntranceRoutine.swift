import simd

// Original Show: 27 played frames at 100 ms. Stage travel follows the measured
// purple-body bounds; articulation is authored separately from that trajectory.
enum VineEntranceRoutine {
    static let duration=2.70
    private static let size=ContinuousTrack([(0,0.001),(0.1,0.035),(0.5,0.063),(1,0.162),(1.3,0.306),(1.5,0.514),(1.7,0.75),(1.9,1),(2.7,1)])
    private static let x=ContinuousTrack([(0,-0.1),(0.5,-0.36),(1,-0.75),(1.4,-0.90),(1.7,-0.61),(1.9,-0.28),(2.1,0),(2.7,0)])
    private static let y=ContinuousTrack([(0,1.08),(0.5,0.80),(1,0.365),(1.3,0.12),(1.5,-0.03),(1.7,0.057),(1.9,0.49),(2,0.49),(2.2,0),(2.7,0)])
    static let grip=SIMD3<Float>(-0.26,0.92,0.46)
    static func sample(at t:Double)->RoutinePose {
        let release=RoutineLibrary.smooth(t,1.96,2.12)
        let recover=RoutineLibrary.smooth(t,2.28,2.64)
        let tuck=RoutineLibrary.smooth(t,1.40,1.85)*(1-RoutineLibrary.smooth(t,2.0,2.2))
        let crouch=RoutineLibrary.smooth(t,2.10,2.23)*(1-RoutineLibrary.smooth(t,2.27,2.58))
        let vineRotation=simd_quatf(angle:-0.35+0.08*tuck,axis:SIMD3<Float>(0,0,1))
        let bend:Float=0.2+1.6*release
        let separation:Float=0.26
        let angle=bend*separation/VineGeometry.length
        let along=SIMD3<Float>((cos(angle)-1)*VineGeometry.length/bend,sin(angle)*VineGeometry.length/bend,0)
        let vineOrigin=grip-vineRotation.act(along)
        var pose=RoutinePose(actorPlacement:ActorPlacement(offset:[x.sample(at:t),y.sample(at:t),0],rotation:simd_quatf(angle:-0.45*tuck,axis:[1,0,0]),scale:size.sample(at:t)))
        pose.headPitch=0.25*crouch-0.12*tuck
        pose.face=FacialIntent(eyeClosure:0.45*crouch,smileOffset:0.15*tuck)
        pose.stance.pelvisOffset=[0,-0.20*crouch,0]
        for side in FootSide.allCases {
            pose.stance.feet[side]=FootIntent(ankle:[side.sign*(0.25+0.15*tuck),-0.78+0.43*tuck,0.05+0.34*tuck],rotation:simd_quatf(angle:-1.25*tuck,axis:[1,0,0]),kneeBend:[side.sign*0.5,0,1],weight:1-recover)
        }
        for side in HandSide.allCases {
            let second=side == .right ? RoutineLibrary.smooth(t,1.30,1.55):Float(1)
            let contact=side == .left ? grip:vineOrigin
            let gripping=HandOrientation(fingers:[-side.sign,0,0],palm:[0,0,side.sign])
            let free=RoutineLibrary.handOnBelly(side,weight:1)
            let reaching=HandOrientation(fingers:free.fingers,palm:free.palm).blended(to:gripping,weight:second)
            let landingFrame=HandOrientation(fingers:[0,-1,0],palm:[-side.sign,0,0])
            let orientation=reaching.blended(to:landingFrame,weight:release)
            let settleArms=RoutineLibrary.smooth(t,2.12,2.21)
            var shoulder=SIMD3<Float>(side.sign*0.11,0.04,side == .left ? 1/3:0.40)
            var elbow=side == .left ? SIMD3<Float>(-1,1.20,0.10):SIMD3<Float>(1,-0.40,1.90)
            shoulder += (SIMD3<Float>(0,0.04,0.12)-shoulder)*settleArms
            elbow += (SIMD3<Float>(side.sign,0,0.4)-elbow)*settleArms
            let airborne=HandIntent(wrist:.zero,fingers:orientation.fingers,palm:orientation.palm,openness:0.3,weight:second,grip:1,fingersTogether:1,thumbFold:0.90,palmContact:contact,shoulderOffset:shoulder,elbowBend:elbow)
            var hand=airborne
            let landing=SIMD3<Float>(side.sign*0.55,-0.48-0.12*crouch,0.23)
            hand.palmContact=contact+(landing-contact)*release+SIMD3<Float>(side.sign*0.32,0,0.40)*sin(Float.pi*release)
            hand.grip *= second*(1-release);hand.thumbFold *= second*(1-release)
            hand.weight=max(second,release)*(1-recover)
            if side == .right && second<1 && release==0 {
                hand.palmContact=free.wrist+(contact-free.wrist)*second+SIMD3<Float>(0,0,0.30*sin(Float.pi*second))
                hand.weight=1
            }
            pose.hands[side]=hand
        }
        if t<2.20 {
            let drift=RoutineLibrary.smooth(t,2.02,2.20)
            pose.props.append(PropCue(id:"entrance.vine",kind:.vine,anchor:.character,offset:vineOrigin+SIMD3(0,2*drift,0),rotation:vineRotation,visibility:1-drift,deformation:.vine(bend:0.2+1.6*release)))
        }
        if t>2.15 && t<2.60 {
            let age=Float((t-2.15)/0.45),grow=RoutineLibrary.smooth(t,2.15,2.20),fade=1-RoutineLibrary.smooth(t,2.35,2.60)
            for side:Float in [-1,1] {for i in 0..<3 {
                let radius:Float=(0.055+0.015*Float(i))*grow*fade
                if radius>0.001 {
                    pose.props.append(PropCue(id:"entrance.dust.\(side).\(i)",kind:.dustCloud,anchor:.stage,offset:[side*(0.27+0.10*Float(i)+0.22*age),-0.85+0.03*Float(i)+0.07*age,0.03+0.06*Float(i)],scale:[radius*1.4,radius*0.7,radius]))
                }
            }}
        }
        return pose
    }
}
