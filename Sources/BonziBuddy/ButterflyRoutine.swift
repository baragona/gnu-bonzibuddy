import simd

enum ButterflyRoutine {
    static let duration=10.30
    static let flight=MotionPath([
        (0,[-1.25,-0.02,0.35]),(0.4,[-1.18,0.16,0.35]),(0.8,[-1.08,0.52,0.4]),
        (1.2,[-0.92,0.98,0.32]),(1.7,[-0.72,0.85,0.32]),
        (7.8,[-0.72,0.85,0.32]),(8.1,[-0.80,1.15,0.32]),(8.5,[-0.20,1.40,0.32]),
        (9.0,[0.70,1.15,0.32]),(9.6,[1.30,0.70,0.32]),(10.3,[1.35,0.60,0.32])
    ])
    static func sample(at t:Double)->RoutinePose {
        let raised=RoutineLibrary.smooth(t,1.1,1.7)*(1-RoutineLibrary.smooth(t,8.2,9.3))
        let touching=RoutineLibrary.smooth(t,3.4,3.9)*(1-RoutineLibrary.smooth(t,6.2,6.7))
        let left=HandIntent(wrist:[-0.73,0.35,0.34],fingers:[-0.05,1,0],palm:[0,0,1],weight:raised,pointing:true)
        let right=HandIntent(wrist:[-0.54,0.50+0.015*sin(Float(t)*9)*touching,0.34],fingers:[-0.80,0.55,-0.08],palm:[0,0,1],weight:touching,pointing:true)
        let landed=RoutineLibrary.smooth(t,1.35,1.7)*(1-RoutineLibrary.smooth(t,7.8,8.1))
        let airborne=PropAnchor.transformed(.character,offset:flight.sample(at:t),rotation:simd_quatf(angle:0,axis:[0,1,0]))
        let perch=PropAnchor.transformed(.attachment(.indexTip(.left)),offset:[0,0.075,0],rotation:simd_quatf(angle:0,axis:[0,1,0]))
        let anchor=PropAnchor.blend(airborne,perch,weight:landed)
        let visibility=RoutineLibrary.smooth(t,0.1,0.3)*(1-RoutineLibrary.smooth(t,9.35,9.6))
        let flap=Float(0.5+0.5*sin(t*2*Double.pi*7))
        let angle:Float=(0.12+1.1*flap)*(1-landed)+(0.30+0.22*Float(sin(t*5)))*landed
        let scale=SIMD3<Float>(repeating:1.10)
        var props=[PropCue(id:"butterfly.body",kind:.butterflyBody,anchor:anchor,offset:.zero,scale:scale,visibility:visibility)]
        for (id,rotation) in [("left",Float.pi-angle),("right",angle)] {
            props.append(PropCue(id:"butterfly.\(id)",kind:.butterflyWing,anchor:anchor,offset:.zero,rotation:simd_quatf(angle:rotation,axis:[0,1,0]),scale:scale,visibility:visibility))
        }
        let blow=RoutineLibrary.smooth(t,7.0,7.2)*(1-RoutineLibrary.smooth(t,7.6,7.8))
        return RoutinePose(hands:[.left:left,.right:right],bodyYaw:-0.48*raised,headYaw:-0.12*raised,headTilt:-0.035*raised,face:FacialIntent(jawOpening:0.08*blow,gaze:[-0.55*raised,0.25*raised],smileOffset:-0.15*blow),props:visibility>0 ? props:[])
    }
}
