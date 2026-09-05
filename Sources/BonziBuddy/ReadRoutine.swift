import simd

enum ReadRoutine {
    static let duration=11.61
    static let bookScale:Float=1.50
    static let holdRange=4.30..<9.05
    private static let center=MotionTrack<SIMD3<Float>>([
        (0,[0.62,-0.50,-0.25]),(1.65,[0.62,-0.50,-0.25]),(1.90,[0.62,-0.55,0.30]),
        (2.20,[0,-0.40,0.42]),(9.35,[0,-0.40,0.42]),(9.65,[0.62,-0.55,0.30]),
        (10.12,[0.62,-0.50,-0.25]),(11.61,[0.62,-0.50,-0.25])
    ])
    static func sample(at t:Double)->RoutinePose {
        let sit=RoutineLibrary.smooth(t,0.15,0.65)*(1-RoutineLibrary.smooth(t,10.70,11.50))
        var stance=StanceIntent(pelvisOffset:[0,-0.30*sit,-0.10*sit])
        for side in FootSide.allCases {
            stance.feet[side]=FootIntent(ankle:[side.sign*0.34,-0.785+0.05*sin(Float.pi*sit),0.10],rotation:simd_quatf(angle:-side.sign*0.38,axis:[0,0,1])*simd_quatf(angle:side.sign*0.25,axis:[0,1,0])*simd_quatf(angle:-1.10,axis:[1,0,0]),kneeBend:[side.sign*0.55,1,0.15],weight:sit)
        }
        let opened=RoutineLibrary.smooth(t,1.95,2.25)*(1-RoutineLibrary.smooth(t,9.30,9.60))
        let angle=Float.pi/2+(0.35-Float.pi/2)*opened
        let rotation=simd_quatf(angle:0.45*opened,axis:[1,0,0])
        let anchor=PropAnchor.transformed(.character,offset:center.sample(at:t),rotation:rotation)
        let visible=RoutineLibrary.smooth(t,1.60,1.80)*(1-RoutineLibrary.smooth(t,10.00,10.20))
        var props:[PropCue]=[]
        if visible>0 {
            props=[PropCue(id:"read.left",kind:.bookLeft,anchor:anchor,offset:[-0.065*bookScale*(1-opened),0,0],rotation:simd_quatf(angle:-angle,axis:[0,1,0]),scale:SIMD3(repeating:bookScale),visibility:visible),PropCue(id:"read.right",kind:.bookRight,anchor:anchor,offset:[0.065*bookScale*(1-opened),0,0],rotation:simd_quatf(angle:angle,axis:[0,1,0]),scale:SIMD3(repeating:bookScale),visibility:visible)]
        }
        let page=RoutineLibrary.smooth(t,6.10,6.85)
        if t>=6.10 && t<=6.90 {
            let reveal=RoutineLibrary.smooth(t,6.10,6.18)*(1-RoutineLibrary.smooth(t,6.82,6.90))
            props.append(PropCue(id:"read.page",kind:.bookLeaf,anchor:anchor,offset:[0,0,-0.08*bookScale],rotation:simd_quatf(angle:0.35+(Float.pi-0.70)*page,axis:[0,1,0]),scale:SIMD3(repeating:bookScale),visibility:reveal,deformation:.page(curl:sin(Float.pi*page))))
        }
        let held=RoutineLibrary.smooth(t,1.80,2.20)*(1-RoutineLibrary.smooth(t,9.30,9.70))
        let retrieval=RoutineLibrary.smooth(t,0.95,1.35)*(1-RoutineLibrary.smooth(t,1.95,2.20))
        let stow=RoutineLibrary.smooth(t,9.30,9.65)*(1-RoutineLibrary.smooth(t,10.10,10.40))
        let push=RoutineLibrary.smooth(t,10.50,10.90)*(1-RoutineLibrary.smooth(t,11.15,11.55))
        let turnHand=RoutineLibrary.smooth(t,5.65,5.95)*(1-RoutineLibrary.smooth(t,6.95,7.20))
        var hands:[HandSide:HandIntent]=[:]
        for side in [HandSide.left,.right] {
            let halfRotation=simd_quatf(angle:side.sign*angle,axis:[0,1,0])
            var wrist=center.sample(at:t)+rotation.act(halfRotation.act(SIMD3<Float>(side.sign*0.42,-0.18,0.070)*bookScale))
            var weight=held
            if side == .right {
                let reach=max(retrieval,stow)
                wrist += (center.sample(at:t)+SIMD3<Float>(0.10,-0.12,0.02)-wrist)*reach
                weight=max(weight,reach)
            } else {
                let wet=1-RoutineLibrary.smooth(t,6.10,6.30)
                let target=SIMD3<Float>((0.22-0.44*page)*(1-wet)-0.08*wet,0.02-0.10*wet,0.32+0.10*wet)
                wrist += (target-wrist)*turnHand
                weight=max(weight,turnHand)
            }
            wrist += (SIMD3<Float>(side.sign*0.53,-0.70,0.12)-wrist)*push
            weight=max(weight,push)
            let pageReach=side == .left ? turnHand*RoutineLibrary.smooth(t,6.05,6.25):0
            let turnRotation=simd_quatf(angle:Float.pi*pageReach,axis:[1,0,0])
            let heldFingers=turnRotation.act(rotation.act(halfRotation.act(SIMD3<Float>(0,1,0))))
            let heldPalm=turnRotation.act(rotation.act(halfRotation.act(SIMD3<Float>(0,0,-1))))
            let fingers=heldFingers+(SIMD3<Float>(side.sign,0,-0.1)-heldFingers)*push
            let palm=heldPalm+(SIMD3<Float>(0,-1,0)-heldPalm)*push
            hands[side]=HandIntent(wrist:wrist,fingers:fingers,palm:palm,weight:weight,grip:0.22*(1-push))
        }
        let reading=RoutineLibrary.smooth(t,2.10,2.40)*(1-RoutineLibrary.smooth(t,9.10,9.40))
        let gazeX:Float=0.28*sin(Float(t-4.3)*2*Float.pi/4.75)*reading
        return RoutinePose(hands:hands,headPitch:0.14*reading,face:FacialIntent(eyeClosure:0.18*reading,gaze:[gazeX,-0.85*reading]),props:props,stance:stance)
    }
}
