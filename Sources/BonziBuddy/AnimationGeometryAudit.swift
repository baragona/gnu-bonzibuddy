import AppKit
import MetalKit
import simd

struct AuditFrame {let bones:[Instance];let props:[PropDraw];let morphs:FanMorphUniforms}
private func auditXYZ(_ p:SIMD4<Float>)->SIMD3<Float> {SIMD3(p.x,p.y,p.z)}
private func auditArray(_ p:SIMD3<Float>)->[Float] {[p.x,p.y,p.z]}
private func auditName(_ s:String)->String {s.lowercased().replacingOccurrences(of:" ",with:"-")}
private func auditDirections(_ rig:FanRig,_ bones:[Instance],_ side:HandSide)->(SIMD3<Float>,SIMD3<Float>,SIMD3<Float>,SIMD3<Float>) {
    let wrist=side == .left ? 26:42,knuckle=side == .left ? 30:46,index=side == .left ? 27:43
    let origin=auditXYZ(bones[wrist].model*rig.rest[wrist].columns.3)
    let hand=normalize(auditXYZ(bones[knuckle].model*rig.rest[knuckle].columns.3)-origin)
    let old=normalize(auditXYZ(rig.rest[knuckle].columns.3-rig.rest[wrist].columns.3))
    let oldPalm=normalize(SIMD3<Float>(0,-1,0)-old*dot(SIMD3<Float>(0,-1,0),old))
    let mapped=auditXYZ(bones[wrist].model*SIMD4(oldPalm,0))
    let palm=normalize(mapped-hand*dot(mapped,hand))
    let tip=auditXYZ(rig.attachmentFrame(.indexTip(side),axes:.character,bones:bones).columns.3)
    let pointing=normalize(tip-auditXYZ(bones[index].model*rig.rest[index].columns.3))
    return (origin,hand,palm,pointing)
}
final class AuditGPU {
    let renderer:Renderer,fan:MTLComputePipelineState,prop:MTLComputePipelineState
    let palette:MTLBuffer,fanOutput:MTLBuffer
    var outputs:[String:MTLBuffer]=[:]
    init(_ renderer:Renderer) throws {
        self.renderer=renderer
        let url=Bundle.main.url(forResource:"Shaders",withExtension:"metal") ?? URL(fileURLWithPath:"Sources/BonziBuddy/Shaders.metal")
        let library=try renderer.device.makeLibrary(source:String(contentsOf:url,encoding:.utf8),options:nil)
        fan=try renderer.device.makeComputePipelineState(function:library.makeFunction(name:"auditFanPositions")!)
        prop=try renderer.device.makeComputePipelineState(function:library.makeFunction(name:"auditPropPositions")!)
        palette=renderer.device.makeBuffer(length:128*MemoryLayout<Instance>.stride)!
        fanOutput=renderer.device.makeBuffer(length:Int(renderer.fanMorphVertexCount)*16)!
    }
    func positions(_ frame:AuditFrame) throws -> ([SIMD3<Float>],[String:[SIMD3<Float>]]) {
        let command=renderer.queue.makeCommandBuffer()!,encoder=command.makeComputeCommandEncoder()!
        frame.bones.withUnsafeBytes {palette.contents().copyMemory(from:$0.baseAddress!,byteCount:$0.count)}
        var morphs=frame.morphs
        encoder.setComputePipelineState(fan);encoder.setBuffer(renderer.vertices,offset:0,index:0);encoder.setBuffer(palette,offset:0,index:1)
        encoder.setBuffer(renderer.fanMorphBuffer,offset:0,index:3);encoder.setBytes(&morphs,length:MemoryLayout<FanMorphUniforms>.stride,index:4);encoder.setBuffer(fanOutput,offset:0,index:6)
        encoder.dispatchThreads(MTLSize(width:Int(renderer.fanMorphVertexCount),height:1,depth:1),threadsPerThreadgroup:MTLSize(width:64,height:1,depth:1))
        encoder.setComputePipelineState(prop)
        for draw in frame.props {
            let mesh=renderer.propRenderer!.meshes[draw.kind]!,count=mesh.vertices.length/MemoryLayout<PropVertex>.stride
            if outputs[draw.id]?.length != count*16 {outputs[draw.id]=renderer.device.makeBuffer(length:count*16)!}
            let (mode,deformation)=renderer.propRenderer!.packedDeformation(draw.deformation)
            var uniforms=PropUniforms(model:draw.model,color:[1,1,1,1],material:[Float(draw.kind.rawValue),mode,0,0],deformation:deformation),n=UInt32(count)
            encoder.setBuffer(mesh.vertices,offset:0,index:0);encoder.setBytes(&uniforms,length:MemoryLayout<PropUniforms>.stride,index:5)
            encoder.setBuffer(outputs[draw.id],offset:0,index:6);encoder.setBytes(&n,length:4,index:7)
            encoder.dispatchThreads(MTLSize(width:count,height:1,depth:1),threadsPerThreadgroup:MTLSize(width:64,height:1,depth:1))
        }
        encoder.endEncoding();command.commit();command.waitUntilCompleted()
        if let error=command.error {throw error}
        func read(_ buffer:MTLBuffer)->[SIMD3<Float>] {(0..<(buffer.length/16)).map {auditXYZ(buffer.contents().load(fromByteOffset:$0*16,as:SIMD4<Float>.self))}}
        let body=read(fanOutput),props=Dictionary(uniqueKeysWithValues:frame.props.map {($0.id,read(outputs[$0.id]!))})
        guard body.allSatisfy({$0.x.isFinite && $0.y.isFinite && $0.z.isFinite}),props.values.allSatisfy({$0.allSatisfy({$0.x.isFinite && $0.y.isFinite && $0.z.isFinite})}) else {throw failure("Nonfinite GPU audit positions")}
        return (body,props)
    }
}

func auditAnimationGeometry() throws {
    try auditGeometrySelfCheck()
    func argument(_ name:String)->String? {CommandLine.arguments.firstIndex(of:name).flatMap {$0+1<CommandLine.arguments.count ? CommandLine.arguments[$0+1]:nil}}
    let fps=Double(argument("--audit-fps") ?? "30") ?? 30
    guard fps>0,fps<=120 else {throw failure("Audit FPS must be in (0,120]")}
    guard let device=MTLCreateSystemDefaultDevice() else {throw failure("Metal unavailable")}
    let requested=argument("--action"),wearables=CommandLine.arguments.contains("--with-wearables")
    let actions=Action.allCases.filter {requested==nil || $0.rawValue.lowercased()==requested!.lowercased()}
    guard !actions.isEmpty else {throw failure("Unknown audit action")}
    let root=argument("--audit-output") ?? ("Validation/GeometryAudit"+(wearables ? "-wearables":""))
    try FileManager.default.createDirectory(atPath:root,withIntermediateDirectories:true)
    func save(_ value:Any,_ path:String) throws {try JSONSerialization.data(withJSONObject:value,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:path))}
    var summaries:[[String:Any]]=[]
    for action in actions {
        let renderer=try Renderer(device:device,previewMesh:URL(fileURLWithPath:"Resources/FanModel/FanRigged.mesh"),rigURL:URL(fileURLWithPath:"Resources/FanModel/FanRig.json"))
        renderer.fanLiveActions=true;renderer.fanTeethEnabled=true
        if let path=argument("--audit-hand-patch") {renderer.fanRig!.auditPoseAdjustment=try AuditHandPosePatch.load(path)}
        if wearables {renderer.character.setSunglassesEnabled(true,at:-5);renderer.character.setHeadphonesEnabled(true,at:-5)}
        renderer.character.play(action,at:0)
        var captured:AuditFrame?
        renderer.onAuditFrame={captured=AuditFrame(bones:$0,props:$1,morphs:$2)}
        if let t=argument("--audit-render-time").flatMap(Double.init) {
            try renderAuditPose(renderer:renderer,action:action,time:t,folder:root)
            continue
        }
        let gpu=try AuditGPU(renderer),rig=renderer.fanRig!
        let count=Int(renderer.fanMorphVertexCount),ptr=renderer.vertices.contents()
        let rest=(0..<count).map {auditXYZ(ptr.load(fromByteOffset:$0*128,as:SIMD4<Float>.self))}
        let names=["body","left.upper-arm","left.forearm","left.hand","right.upper-arm","right.forearm","right.hand"]
        let groups=(0..<count).map {i -> Int in
            var joint=0,weight:Float=0
            for lane in 0..<8 {
                let w=ptr.load(fromByteOffset:i*128+(24+lane)*4,as:Float.self)
                if w>weight {weight=w;joint=Int(ptr.load(fromByteOffset:i*128+(16+lane)*4,as:Float.self))}
            }
            switch joint {case 22:return 1;case 23:return 2;case 24...38:return 3;case 39:return 4;case 40:return 5;case 41...54:return 6;default:return 0}
        }
        var grouped=[[SIMD3<Int>]](repeating:[],count:7)
        for i in stride(from:0,to:renderer.indexCount,by:3) {
            let ids=SIMD3<Int>((0..<3).map {Int(renderer.indices.contents().load(fromByteOffset:(i+$0)*4,as:UInt32.self))})
            // Exclude mixed region boundary triangles at connected joints.
            if groups[ids.x]==groups[ids.y] && groups[ids.y]==groups[ids.z] {grouped[groups[ids.x]].append(ids)}
        }
        let bodyBVH=AuditBVH(indices:grouped[0],points:rest)
        let armBVHs=(1...6).map {AuditBVH(indices:grouped[$0],points:rest)}
        var propBVHs:[String:AuditBVH]=[:]
        let duration=action == .idle ? 4.6:action == .speak ? 2:action.duration
        var frames:[[String:Any]]=[],peaks:[String:[String:Any]]=[:],occurrences:[String:Int]=[:]
        let sampleTime=argument("--audit-sample-time").flatMap(Double.init)
        if argument("--audit-sample-time") != nil {
            guard let sampleTime,sampleTime.isFinite,sampleTime>=0,sampleTime<=duration else {throw failure("Invalid audit sample time")}
            _=try renderer.offscreen(width:160,height:128,at:0)
        }
        let times=sampleTime.map {[$0]} ?? (0...Int(ceil(duration*fps))).map {min(duration,Double($0)/fps)}
        for t in times {
            _=try renderer.offscreen(width:160,height:128,at:t)
            guard let snapshot=captured else {throw failure("Missing audit frame")}
            let (points,props)=try gpu.positions(snapshot)
            bodyBVH.refit(points);for tree in armBVHs {tree.refit(points)}
            for draw in snapshot.props {
                if propBVHs[draw.id]==nil {
                    let mesh=renderer.propRenderer!.meshes[draw.kind]!
                    let indices=stride(from:0,to:mesh.indexCount,by:3).map {i in SIMD3<Int>((0..<3).map {Int(mesh.indices.contents().load(fromByteOffset:(i+$0)*4,as:UInt32.self))})}
                    propBVHs[draw.id]=AuditBVH(indices:indices,points:props[draw.id]!)
                }
                propBVHs[draw.id]!.refit(props[draw.id]!)
            }
            var crossings:[String:(Int,AuditBounds)]=[:]
            for group in 1...6 {
                var targets:[(String,AuditBVH)]=[("body",bodyBVH)]
                targets += snapshot.props.map {($0.id,propBVHs[$0.id]!)}
                if group<=3 {targets += (4...6).map {(names[$0],armBVHs[$0-1])}}
                for (name,tree) in targets {
                    let key=names[group]+" / "+name
                    var hits=0,bounds=AuditBounds()
                    for triangle in armBVHs[group-1].triangles {
                        tree.crossings(triangle) {crossed in
                            // Connected shoulder embedding is expected; retain
                            // crossings farther from the joint as audit candidates.
                            if name=="body" && (group==1 || group==4) {
                                let joint=group==1 ? 22:39,shoulder=auditXYZ(snapshot.bones[joint].model*rig.rest[joint].columns.3)
                                if crossed.allSatisfy({length($0-shoulder)<0.12}) {return}
                            }
                            hits+=1;for point in crossed {bounds.include(point)}
                        }
                    }
                    if hits>0 {crossings[key]=(hits,bounds)}
                }
            }
            var collisions:[[String:Any]]=[]
            for (pair,(hits,bounds)) in crossings.sorted(by:{$0.key<$1.key}) {
                let span=bounds.hi-bounds.lo
                let record:[String:Any]=["pair":pair,"trianglePairs":hits,"span":auditArray(span),"center":auditArray((bounds.lo+bounds.hi)/2),"time":t]
                collisions.append(record);occurrences[pair,default:0]+=1
                if hits>(peaks[pair]?["trianglePairs"] as? Int ?? 0) {peaks[pair]=record}
            }
            var directions:[[String:Any]]=[]
            for side in HandSide.allCases {
                let (wrist,hand,palm,index)=auditDirections(rig,snapshot.bones,side)
                var row:[String:Any]=["side":side.rawValue,"wrist":auditArray(wrist),"handDirection":auditArray(hand),"palmNormal":auditArray(palm),"indexDirection":auditArray(index),"handYawDegrees":atan2(hand.x,hand.z)*180/Float.pi,"handElevationDegrees":atan2(hand.y,hypot(hand.x,hand.z))*180/Float.pi]
                if let intent=rig.routine.hands[side] {
                    let desired=normalize(auditXYZ(snapshot.bones[0].model*SIMD4(intent.fingers,0)))
                    let mappedPalm=auditXYZ(snapshot.bones[0].model*SIMD4(intent.palm,0))
                    let desiredPalm=normalize(mappedPalm-desired*dot(mappedPalm,desired))
                    row["intentHandDirection"]=auditArray(desired);row["intentPalmNormal"]=auditArray(desiredPalm)
                    row["palmIntentErrorDegrees"]=acos(min(1,max(-1,dot(desiredPalm,palm))))*180/Float.pi
                    row["grip"]=intent.grip;row["fist"]=intent.fist;row["pointing"]=intent.pointing;row["intentWeight"]=intent.weight;row["intentErrorDegrees"]=acos(min(1,max(-1,dot(desired,hand))))*180/Float.pi
                }
                directions.append(row)
            }
            frames.append(["time":t,"hands":directions,"crossings":collisions])
        }
        let peakRows=peaks.keys.sorted().map {key -> [String:Any] in var row=peaks[key]!;row["sampledFramesWithCrossing"]=occurrences[key]!;return row}
        var summary:[String:Any]=["cameraYawRadians":renderer.character.yaw,"cameraPitchRadians":renderer.character.pitch,"action":action.rawValue,"fps":fps,"frames":frames.count,"wearables":wearables,"peaks":peakRows]
        if let sampleTime {summary["singleSampleTime"]=sampleTime}
        if let path=argument("--audit-hand-patch") {summary["poseStudyPatch"]=path}
        try save(["summary":summary,"frames":frames],"\(root)/\(auditName(action.rawValue)).json")
        summaries.append(summary)
        try save(summaries,"\(root)/summary.json")
        print("Audited \(action.rawValue): \(frames.count) samples, \(peaks.count) crossing pairs")
        fflush(stdout)
    }
}

private func renderAuditPose(renderer:Renderer,action:Action,time:Double,folder:String) throws {
    var capturedBones:[Instance]=[]
    renderer.onAuditFrame={bones,_,_ in capturedBones=bones}
    // Prime playback at the clip start so a random-access diagnostic frame
    // includes its authored facial state, just like sequential playback.
    _=try renderer.offscreen(width:160,height:128,at:0)
    for (name,yaw) in [("front",Float(0)),("quarter",-Float.pi/4),("left",-Float.pi/2),("right",Float.pi/2)] {
        renderer.character.yaw=yaw
        let (texture,_)=try renderer.offscreen(width:800,height:640,at:time)
        let path="\(folder)/\(auditName(action.rawValue))-\(String(format:"%.3f",time))-\(name).png"
        try writePNG(texture,to:path)
        let rig=renderer.fanRig!,bones=capturedBones
        let picture=NSImage(size:NSSize(width:800,height:640))
        picture.lockFocus();NSColor(calibratedWhite:0.94,alpha:1).setFill();NSRect(x:0,y:0,width:800,height:640).fill()
        NSImage(contentsOfFile:path)!.draw(in:NSRect(x:0,y:0,width:800,height:640))
        func point(_ p:SIMD3<Float>)->NSPoint {let q=renderer.projection(width:800,height:640)*SIMD4(p,1);return NSPoint(x:CGFloat(q.x/q.w+1)*400,y:CGFloat(q.y/q.w+1)*320)}
        func arrow(_ start:SIMD3<Float>,_ vector:SIMD3<Float>,_ color:NSColor) {
            let a=point(start),b=point(start+vector),line=NSBezierPath();color.setStroke();line.lineWidth=2.5;line.move(to:a);line.line(to:b)
            let angle=atan2(b.y-a.y,b.x-a.x)
            for delta:CGFloat in [-0.5,0.5] {line.move(to:b);line.line(to:NSPoint(x:b.x-9*cos(angle+delta),y:b.y-9*sin(angle+delta)))}
            line.stroke()
        }
        for side in HandSide.allCases {
            let (wrist,hand,palm,index)=auditDirections(rig,bones,side)
            arrow(wrist,hand*0.22,.systemBlue);arrow(wrist,palm*0.18,.systemOrange);arrow(wrist,index*0.18,.systemGreen)
        }
        ("Blue: hand axis   Orange: palm normal   Green: index direction" as NSString).draw(at:NSPoint(x:12,y:12),withAttributes:[.foregroundColor:NSColor.black,.font:NSFont.systemFont(ofSize:14)])
        picture.unlockFocus()
        try NSBitmapImageRep(data:picture.tiffRepresentation!)!.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:path))
    }
}
