import simd

// Shared stationary mailbox. Its stage anchor lets the actor turn independently.
enum MailboxScene {
    static let origin=SIMD3<Float>(-1.05,0.10,0)
    static let rotation=simd_quatf(angle:-0.35,axis:SIMD3<Float>(0,1,0))
    static func cues(visibility visible:Float,opening:Float)->[PropCue] {
        guard visible>0 else {return []}
        let root=PropAnchor.transformed(.stage,offset:origin,rotation:rotation)
        let anchor=PropAnchor.transformed(root,offset:[0,-1.0*(1-visible),0],rotation:simd_quatf(angle:0,axis:[0,1,0]))
        return [PropCue(id:"mail.box",kind:.mailbox,anchor:anchor,offset:.zero,visibility:visible),
                PropCue(id:"mail.door",kind:.mailboxDoor,anchor:anchor,offset:SIMD3<Float>(0.265,-0.155,0)*visible,rotation:simd_quatf(angle:-2.80*opening,axis:[0,0,1]),visibility:visible),
                PropCue(id:"mail.flag",kind:.bananaFruit,anchor:anchor,offset:SIMD3<Float>(0.12,0.16,0.12)*visible,scale:[0.32,0.30,0.32],visibility:visible,deformation:.fruit(remaining:1)),
                PropCue(id:"mail.flag.peel",kind:.bananaPeel,anchor:anchor,offset:SIMD3<Float>(0.12,0.16,0.12)*visible,scale:[0.32,0.30,0.32],visibility:visible,deformation:.peel(openings:.zero))]
    }
}
