import simd

// Pure scene descriptions: no Metal types, mesh buffers, or skeleton indices.
enum PropKind: Int, CaseIterable {
    // Stable material IDs consumed by the Metal prop fragment function.
    case globe=0, coconut=1, bananaFruit=2, bananaPeel=3
}
enum PropAnchor {
    case character
    case attachment(RigAttachment,axes:AttachmentAxes = .character)
}
enum PropDeformation {
    case rigid
    case peel(openings:SIMD3<Float>)
    case fruit(remaining:Float)
}
struct PropCue {
    var id:String
    var kind:PropKind
    var anchor:PropAnchor
    var offset:SIMD3<Float>
    var rotation=simd_quatf(angle:0,axis:[0,1,0])
    var scale=SIMD3<Float>(repeating:1)
    var visibility:Float=1
    var deformation:PropDeformation = .rigid
}
struct PropDraw {
    var id:String
    var kind:PropKind
    var model:simd_float4x4
    var deformation:PropDeformation = .rigid
}

// Stateful playback, separate from GPU rendering. Snapshots are stored in the
// character frame, so retiring props remain consistent when the camera changes.
final class PropMotion {
    private var action:Action?
    private var started:Double?
    private var lastTime:Double = -.infinity
    private var shown:[PropDraw]=[]
    private var retiring:[PropDraw]=[]
    private var retiredAt:Double=0
    func sample(action next:Action,started nextStart:Double,at time:Double,cues:[PropCue],rig:FanRig,bones:[Instance])->[PropDraw] {
        if time<lastTime {shown=[];retiring=[];action=nil;started=nil}
        if action != next || started != nextStart {
            retiring=shown;retiredAt=time;action=next;started=nextStart
        }
        let root=bones[0].model,inverseRoot=root.inverse
        var draws:[PropDraw]=[]
        for cue in cues where cue.visibility>0.001 {
            let frame:simd_float4x4
            switch cue.anchor {
            case .character: frame=root
            case let .attachment(attachment,axes): frame=rig.attachmentFrame(attachment,axes:axes,bones:bones)
            }
            let scale=cue.scale*max(0.001,cue.visibility)
            let model=inverseRoot*frame*translation(cue.offset)*simd_float4x4(cue.rotation)*simd_float4x4(diagonal:SIMD4(scale,1))
            draws.append(PropDraw(id:cue.id,kind:cue.kind,model:model,deformation:cue.deformation))
        }
        let remaining=1-RoutineLibrary.smooth(time-retiredAt,0,0.20)
        if remaining>0.001 {
            for old in retiring where !draws.contains(where:{$0.id==old.id}) {
                var draw=old
                draw.model.columns.0 *= remaining;draw.model.columns.1 *= remaining;draw.model.columns.2 *= remaining
                draws.append(draw)
            }
        } else {retiring=[]}
        shown=draws;lastTime=time
        return draws.map {draw in
            var world=draw;world.model=root*draw.model;return world
        }
    }
}
