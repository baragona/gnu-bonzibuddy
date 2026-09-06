import simd

// Original MailCheck (0.90), MailCheckFull (4.30), MailReturn (1.00).
enum MailFullRoutine {
    static let duration=6.20
    static let holdRange=3.45..<5.20
    static let continuation=RoutineContinuation(family:.mail,entryElapsed:3.45,acceptsFrom:0..<5.20,delay:{max(0,3.45-$0)})
    static let packetInside=MailboxScene.origin+MailboxScene.rotation.act(SIMD3<Float>(0,0,0))
    static let packetOutside=MailboxScene.origin+MailboxScene.rotation.act(SIMD3<Float>(0.58,0,0))
    private static let packet=MotionTrack<SIMD3<Float>>([
        (0,packetInside),(1.15,packetInside),(1.65,packetOutside),(1.90,[0,-0.06,0.48]),(6.20,[0,-0.06,0.48])
    ])
    static func sample(at t:Double)->RoutinePose {
        if t>=3.45 {return MailReadRoutine.sample(at:2.10+t-3.45)}
        let boxVisible=RoutineLibrary.smooth(t,0.05,0.35)*(1-RoutineLibrary.smooth(t,2.00,2.40))
        let box=MailboxScene.cues(visibility:boxVisible,opening:RoutineLibrary.smooth(t,0.45,0.85))
        if t<0.90 {
            var pose=MailEmptyRoutine.sample(at:t);pose.props=box;return pose
        }
        let yaw = -0.55*RoutineLibrary.smooth(t,0.90,1.10)*(1-RoutineLibrary.smooth(t,1.60,1.90))
        let facing=simd_quatf(angle:yaw,axis:[0,1,0])
        let center=packet.sample(at:t)
        let rotation=simd_slerp(MailboxScene.rotation,simd_quatf(angle:0,axis:[0,1,0]),RoutineLibrary.smooth(t,1.65,1.90))
        let opened=RoutineLibrary.smooth(t,1.65,2.10)
        let shape=SIMD3<Float>(0.50+0.50*opened,0.25+0.75*opened,1)
        let visible=RoutineLibrary.smooth(t,0.90,1.05)
        var pose=MailReadRoutine.sample(at:2.10)
        let anchor=PropAnchor.transformed(.stage,offset:center,rotation:rotation)
        for i in pose.props.indices {
            pose.props[i].anchor=anchor
            pose.props[i].offset *= shape
            pose.props[i].scale *= shape
            pose.props[i].visibility=visible
        }
        // The compact packet fits the barrel; expansion begins only after exit.
        // Expansion is stylized, not a physical paper-fold simulation.
        let reach=RoutineLibrary.smooth(t,0.90,1.10)
        let transfer=RoutineLibrary.smooth(t,1.65,1.90)
        for side in HandSide.allCases {
            var hand=pose.hands[side]!
            let heldOffset=hand.wrist-SIMD3<Float>(0,-0.06,0.48)
            var target=center+rotation.act(heldOffset*shape)
            var fingers=rotation.act(hand.fingers)
            if side == .left {
                let pull=center+rotation.act(SIMD3<Float>(0.30,0,0.10))
                target=pull+(target-pull)*transfer
                fingers=rotation.act(simd_quatf(angle:Float.pi*(1-transfer),axis:[0,0,1]).act(SIMD3<Float>(1,0,0)))
            }
            hand.wrist=facing.inverse.act(target)
            hand.fingers=facing.inverse.act(fingers)
            hand.palm=facing.inverse.act(rotation.act(hand.palm))
            hand.weight=reach*(side == .left ? 1:transfer)
            pose.hands[side]=hand
        }
        pose.bodyYaw=yaw
        let reading=RoutineLibrary.smooth(t,2.35,2.65)
        pose.headYaw = -0.20*(1-reading)*reach
        pose.headPitch=0.08*reading
        pose.face=FacialIntent(eyeClosure:0.12*reading,gaze:[-0.45*(1-reading)*reach,-0.60*reading])
        pose.props=box+pose.props
        return pose
    }
}
