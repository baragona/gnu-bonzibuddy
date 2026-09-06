import MetalKit
import simd

func validateActorPlacement() throws {
    guard let device=MTLCreateSystemDefaultDevice() else {throw failure("Metal unavailable")}
    let renderer=try Renderer(device:device,previewMesh:URL(fileURLWithPath:"Resources/FanModel/FanRigged.mesh"),rigURL:URL(fileURLWithPath:"Resources/FanModel/FanRig.json"))
    renderer.fanLiveActions=true
    renderer.character.setSunglassesEnabled(true,at:-5)
    renderer.character.setHeadphonesEnabled(true,at:-5)
    let gpu=try AuditGPU(renderer)
    var placement=ActorPlacement(),captured:AuditFrame?
    renderer.fanRig!.auditPoseAdjustment={pose in
        pose.actorPlacement=placement
        pose.props += [
            PropCue(id:"stage",kind:.coconut,anchor:.stage,offset:[0.7,-0.8,0],scale:SIMD3(repeating:0.08)),
            PropCue(id:"held",kind:.coconut,anchor:.attachment(.wrist(.left),axes:.joint),offset:[0,0,0.2],scale:SIMD3(repeating:0.08)),
            PropCue(id:"transfer",kind:.coconut,anchor:.blend(.attachment(.wrist(.left),axes:.joint),.attachment(.head,axes:.joint),weight:0.4),offset:[0.1,0,0],scale:SIMD3(repeating:0.08))
        ]
    }
    renderer.onAuditFrame={captured=AuditFrame(bones:$0,props:$1,morphs:$2)}
    _=try renderer.offscreen(width:160,height:128,at:0)
    var bodyError:Float=0,propError:Float=0,stageError:Float=0,samples=0,vertexCount=0
    let folder="Validation/ActorPlacement"
    try FileManager.default.createDirectory(atPath:folder,withIntermediateDirectories:true)
    for (name,yaw) in [("front",Float(0)),("quarter",-Float.pi/4),("left",-Float.pi/2)] {
        renderer.character.yaw=yaw
        placement=ActorPlacement()
        _=try renderer.offscreen(width:160,height:128,at:1)
        let baseline=try gpu.positions(captured!),stage=renderer.fanRig!.stageFrame
        vertexCount=baseline.0.count
        guard baseline.1.count>=5 else {throw failure("Placement test missing worn or diagnostic props")}
        for scale:Float in [0.001,0.035,0.3,0.7,1] {
            placement=ActorPlacement(offset:[-0.2,0.25,0.1],rotation:simd_quatf(angle:0.4,axis:normalize(SIMD3<Float>(1,1,0))),scale:scale)
            guard placement.isValid else {throw failure("Invalid placement fixture")}
            let (texture,_)=try renderer.offscreen(width:400,height:320,at:1)
            let actual=try gpu.positions(captured!),transform=stage*placement.matrix*stage.inverse
            func error(_ old:SIMD3<Float>,_ new:SIMD3<Float>,_ matrix:simd_float4x4)->Float {
                let expected=matrix*SIMD4(old,1)
                return length(new-SIMD3(expected.x,expected.y,expected.z))
            }
            for i in baseline.0.indices {bodyError=max(bodyError,error(baseline.0[i],actual.0[i],transform))}
            for (id,points) in baseline.1 {
                guard let moved=actual.1[id],moved.count==points.count else {throw failure("Placement lost prop \(id)")}
                for i in points.indices {
                    if id=="stage" {stageError=max(stageError,length(points[i]-moved[i]))}
                    else {propError=max(propError,error(points[i],moved[i],transform))}
                }
            }
            if scale==0.7 {try writePNG(texture,to:"\(folder)/placed-\(name).png")}
            samples += 1
        }
    }
    guard bodyError<0.0001,propError<0.0001,stageError<0.0001 else {throw failure("Placement drift: body \(bodyError), props \(propError), stage \(stageError)")}
    var transitionJump:Float=0,settledError:Float=0
    func matrixError(_ a:[Instance],_ b:[Instance])->Float {
        var error:Float=0
        for i in a.indices {for c in 0..<4 {for r in 0..<4 {
            guard a[i].model[c][r].isFinite,b[i].model[c][r].isFinite else {return .infinity}
            error=max(error,abs(a[i].model[c][r]-b[i].model[c][r]))
        }}}
        return error
    }
    let scales:[Float]=[0.001,0.035,0.3,0.7,1]
    for from in scales {for to in scales {
        let url=URL(fileURLWithPath:"Resources/FanModel/FanRig.json")
        let rig=try FanRig(url:url),target=try FanRig(url:url)
        var current=ActorPlacement(offset:[-0.5,0.6,0],rotation:simd_quatf(angle:0.5,axis:[0,0,1]),scale:from)
        rig.auditPoseAdjustment={$0.actorPlacement=current}
        rig.updateLiveAction(.idle,started:0,at:0)
        _=rig.instances(yaw:0,pitch:0,at:0)
        let before=rig.instances(yaw:0,pitch:0,at:0.8)
        current=ActorPlacement(offset:[0.1,0.2,0.1],rotation:simd_quatf(angle:-0.3,axis:[0,1,0]),scale:to)
        rig.updateLiveAction(.wave,started:0.8,at:0.8)
        transitionJump=max(transitionJump,matrixError(before,rig.instances(yaw:0,pitch:0,at:0.8)))
        rig.updateLiveAction(.wave,started:0.8,at:0.9)
        let middle=rig.instances(yaw:0,pitch:0,at:0.9)
        current=ActorPlacement(scale:from)
        rig.updateLiveAction(.idle,started:0.9,at:0.9)
        transitionJump=max(transitionJump,matrixError(middle,rig.instances(yaw:0,pitch:0,at:0.9)))
        target.auditPoseAdjustment={$0.actorPlacement=current}
        target.updateLiveAction(.idle,started:0.9,at:1.15)
        rig.updateLiveAction(.idle,started:0.9,at:1.15)
        settledError=max(settledError,matrixError(rig.instances(yaw:0,pitch:0,at:1.15),target.instances(yaw:0,pitch:0,at:1.15)))
    }}
    guard transitionJump<0.0001,settledError<0.0001 else {throw failure("Placed transition discontinuity: \(transitionJump), settled \(settledError)")}
    let report:[String:Any]=["transitionScalePairs":25,"maximumTransitionStartJump":transitionJump,"maximumTransitionSettledError":settledError,"samples":samples,"bodyVerticesPerSample":vertexCount,"maximumBodyGPUError":bodyError,"maximumAttachedPropGPUError":propError,"maximumStagePropDrift":stageError,"note":"Actual Metal-deformed body and prop vertices across three camera angles and five actor scales. Includes worn sunglasses/headphones, joint-held and blended anchors, and an independent stage object. Flight choreography and hidden-state lifecycle are not implemented by this test."]
    let data=try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys])
    try data.write(to:URL(fileURLWithPath:"\(folder)/checks.json"));print(String(decoding:data,as:UTF8.self))
}
