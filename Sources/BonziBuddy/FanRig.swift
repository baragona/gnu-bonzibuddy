import Foundation
import simd

// Source joint hierarchy; the proprietary SDK is only used by the offline exporter.
struct FanRigDocument: Decodable {
    struct Node: Decodable { let id:Int; let parent:Int; let name:String; let worldMatrix:[[Float]] }
    let version:Int
    let scale:Float
    let sourceFloor:Float
    let sourceCenterZ:Float
    let nodes:[Node]
}
final class FanRig {
    let source:FanRigDocument
    let rest:[simd_float4x4]
    let local:[simd_float4x4]
    let inverseRest:[simd_float4x4]
    var sourcePose=false
    var waveTime:Double?
    var action:Action = .idle
    var actionTime:Double=0
    var waveSwingEnabled=true
    private var displayedPose:[simd_float4x4] = []
    private var transitionPose:[simd_float4x4] = []
    private var transitionStarted:Double = 0
    private var actionStarted:Double?
    func updateLiveAction(_ next:Action, started:Double, at time:Double) {
        if actionStarted != started || action != next {
            transitionPose=displayedPose
            transitionStarted=time
            actionStarted=started
        }
        action=next;actionTime=max(0,time-started)
        waveTime=next == .wave ? actionTime:nil
    }
    init(url:URL) throws {
        source=try JSONDecoder().decode(FanRigDocument.self,from:Data(contentsOf:url))
        guard source.version==1,source.nodes.count<=128,source.scale>0 else { throw failure("Invalid fan rig") }
        var matrices:[simd_float4x4]=[]
        let conversion=translation([0,-0.9-source.sourceFloor*source.scale,source.sourceCenterZ*source.scale])*scaleMatrix([-source.scale,source.scale,-source.scale])
        for (i,n) in source.nodes.enumerated() {
            guard n.id==i,n.parent>=(-1),n.parent<i,n.worldMatrix.count==4,n.worldMatrix.allSatisfy({$0.count==3 && $0.allSatisfy(\.isFinite)}) else { throw failure("Invalid fan joint hierarchy") }
            let c=n.worldMatrix
            let m=simd_float4x4(columns:(SIMD4(c[0][0],c[0][1],c[0][2],0),SIMD4(c[1][0],c[1][1],c[1][2],0),SIMD4(c[2][0],c[2][1],c[2][2],0),SIMD4(c[3][0],c[3][1],c[3][2],1)))
            matrices.append(conversion*m)
        }
        rest=matrices; inverseRest=matrices.map(\.inverse)
        local=source.nodes.enumerated().map { i,n in n.parent<0 ? matrices[i] : matrices[n.parent].inverse*matrices[i] }
    }
    func instances(yaw:Float,pitch:Float,at time:Double)->[Instance] {
        var posed:[simd_float4x4]=[]
        var gestureElbows:[Int:SIMD3<Float>]=[:],gestureWrists:[Int:SIMD3<Float>]=[:]
        func ease(_ x:Float)->Float { let t=min(1,max(0,x));return t*t*(3-2*t) }
        let a=Float(actionTime)
        let actionEnvelope=ease(a/0.35)*ease(Float(max(0,action.duration-actionTime))/0.35)
        func armAction(_ side:Float)->ArmPose? {
            if action == .clap { return ClapAnimation.arm(at:actionTime,side:side) }
            if action == .shrug { return ShrugAnimation.arm(at:actionTime,side:side) }
            var target=ArmPose.rest(side)
            if action == .dance { target=ArmPose(elbow:[side*0.52,-0.08+0.06*sin(a*3+side*0.7),0.08],wrist:[side*0.68,0.13+0.14*sin(a*3+side*0.7),0.26+0.07*cos(a*3)],angle:side*0.7,spread:0.35) }
            else if action == .surprised { target=ArmPose(elbow:[side*0.58,0.39,0],wrist:[side*0.63,0.83,0.04],angle:side * .pi,spread:1) }
            else if action == .think && side>0 { target=ArmPose(elbow:[0.52,-0.1,0.09],wrist:[0.18,0.30,0.38],angle:2.8,spread:0.1) }
            else { return nil }
            return ClapAnimation.interpolate(ArmPose.rest(side),target,actionEnvelope)
        }
        let arms:[Float:ArmPose]=[Float(-1),Float(1)].reduce(into:[:]) { result,side in if let pose=armAction(side) { result[side]=pose } }
        let wt=Float(waveTime ?? -1)
        let wave=waveTime == nil ? 0 : ease(wt/0.5)*(1-ease((wt-2.5)/0.5))
        func blendRotation(_ a:simd_float4x4,_ b:simd_float4x4,_ amount:Float)->simd_float4x4 {
            let delta=b*a.inverse
            let rotation=simd_float3x3(columns:(SIMD3(delta.columns.0.x,delta.columns.0.y,delta.columns.0.z),SIMD3(delta.columns.1.x,delta.columns.1.y,delta.columns.1.z),SIMD3(delta.columns.2.x,delta.columns.2.y,delta.columns.2.z)))
            let q=simd_slerp(simd_quatf(angle:0,axis:[0,0,1]),simd_quatf(rotation),amount)
            let p=SIMD3(a.columns.3.x,a.columns.3.y,a.columns.3.z)
            return translation(p)*simd_float4x4(q)*translation(-p)*a
        }
        let camera=rotate(pitch,[1,0,0])*rotate(yaw,[0,1,0])
        func xyz(_ m:simd_float4x4)->SIMD3<Float> { SIMD3(m.columns.3.x,m.columns.3.y,m.columns.3.z) }
        var knees:[Int:SIMD3<Float>]=[:],ankles:[Int:SIMD3<Float>]=[:]
        if !sourcePose {
            for hip in [12,16] {
                let side:Float=hip==12 ? -1:1
                let h=xyz(rest[hip])+SIMD3<Float>(0,-0.09,0)
                let foot=xyz(rest[hip+2])+SIMD3<Float>(side*0.035,0,0)
                let upper=length(xyz(rest[hip+1])-xyz(rest[hip])),lower=length(xyz(rest[hip+2])-xyz(rest[hip+1]))
                let d=length(foot-h),axis=normalize(foot-h)
                let along=(upper*upper-lower*lower+d*d)/(2*d)
                let pole=SIMD3<Float>(side*0.65,0,0.76)
                let bend=normalize(pole-axis*dot(pole,axis))
                knees[hip]=h+axis*along+bend*sqrt(max(0,upper*upper-along*along))
                ankles[hip]=foot
            }
        }
        for (i,node) in source.nodes.enumerated() {
            var inherited=node.parent<0 ? rest[i] : posed[node.parent]*local[i]
            if !sourcePose {
                if [12,16,20].contains(i) { inherited=translation([0,-0.09,0])*inherited }
                if [23,40,24,41].contains(i) {
                    let reach:Float=(i==23 || i==40) ? 2.3:1.12
                    var extended=local[i];extended.columns.3.x *= reach;extended.columns.3.y *= reach;extended.columns.3.z *= reach
                    inherited=posed[node.parent]*extended
                }
            }
            var result=inherited
            if !sourcePose && i==21 { result=translation([0,0.004*sin(Float(time)*2),0])*inherited }
            if !sourcePose && i==20 && action == .dance {
                let p=xyz(inherited)
                result=translation(p+[0.035*sin(a*3)*actionEnvelope,-0.01*(1-cos(a*6))*actionEnvelope,0])*rotate(0.04*sin(a*3)*actionEnvelope,[0,0,1])*translation(-p)*inherited
            }
            if !sourcePose {
                let side:Float=i<39 ? -1:1
                let restingUpper=SIMD3<Float>(side*0.78,-0.62,0.10)
                let restingForearm=SIMD3<Float>(-side*1.05,i<39 ? 0.62:0.46,0.60)
                func aim(_ child:Int,_ direction:SIMD3<Float>)->simd_float4x4 {
                    let childPosition=inherited*local[child].columns.3
                    let pivot=SIMD3(inherited.columns.3.x,inherited.columns.3.y,inherited.columns.3.z)
                    let from=normalize(SIMD3(childPosition.x,childPosition.y,childPosition.z)-pivot)
                    let rotation=simd_float4x4(simd_quatf(from:from,to:normalize(direction)))
                    return translation(pivot)*rotation*translation(-pivot)*inherited
                }
                func handFrame(_ child:Int,_ direction:SIMD3<Float>,_ palm:SIMD3<Float>)->simd_float4x4 {
                    let oldFinger=normalize(xyz(rest[child])-xyz(rest[i]))
                    let oldPalm=normalize(SIMD3<Float>(0,-1,0)-oldFinger*dot(SIMD3<Float>(0,-1,0),oldFinger))
                    let newFinger=normalize(direction),newPalm=normalize(palm-newFinger*dot(palm,newFinger))
                    let old=simd_float3x3(columns:(oldFinger,oldPalm,cross(oldFinger,oldPalm)))
                    let new=simd_float3x3(columns:(newFinger,newPalm,cross(newFinger,newPalm)))
                    let q=simd_quatf(new*old.transpose)
                    return translation(xyz(inherited))*simd_float4x4(q)*translation(-xyz(rest[i]))*rest[i]
                }
                if i==12 || i==16 { result=aim(i+1,knees[i]!-xyz(inherited)) }
                if i==13 || i==17 { result=aim(i+1,ankles[i-1]!-xyz(inherited)) }
                if i==14 || i==18 {
                    let hip=i-2,legSide:Float=i==14 ? -1:1,p=ankles[hip]!
                    result=translation(p)*rotate(legSide*0.25,[0,1,0])*translation(-xyz(rest[i]))*rest[i]
                }
                if i==56 {
                    let p=xyz(inherited)
                    let glance=(action == .lookLeft || action == .lookRight) ? LookAnimation.yaw(at:actionTime,left:action == .lookLeft) : 0
                    let tilt:Float=action == .think ? -0.08*actionEnvelope : 0
                    result=translation(p)*rotate(glance,[0,1,0])*rotate(tilt)*scaleMatrix([1.13,0.93,1])*translation(-p)*inherited
                }
                if (i==22 || i==39),let pose=arms[side],action == .clap || action == .shrug || action == .think || action == .dance {
                    let elbow=i==22 ? 23:40,hand=i==22 ? 24:41,wrist=i==22 ? 26:42
                    let shoulder=xyz(inherited)
                    let upper=length(xyz(rest[elbow])-xyz(rest[i]))*2.3
                    let lower=length(xyz(rest[hand])-xyz(rest[elbow]))*1.12+length(xyz(rest[wrist])-xyz(rest[hand]))
                    let restElbow=shoulder+normalize(restingUpper)*upper
                    let restWrist=restElbow+normalize(restingForearm)*lower
                    let baseline=ArmPose.rest(side)
                    let engagement=(action == .think || action == .dance) ? actionEnvelope:min(1,(length(pose.wrist-baseline.wrist)+length(pose.elbow-baseline.elbow))*5)
                    var target=action == .think ? SIMD3<Float>(0.23,0.25,0.55):pose.wrist*SIMD3<Float>(0.9,0.9,0.7)+SIMD3<Float>(0,0.11,0.035)
                    if action == .shrug { target.y-=0.13*(1-pose.spread) }
                    if action == .clap { target=SIMD3(pose.wrist.x*0.4,pose.wrist.y*0.9+0.11-(side>0 ? 0.02:0),side<0 ? 0.41:0.30) }
                    let wanted=restWrist+(target-restWrist)*engagement
                    let direction=normalize(wanted-shoulder),distance=min(upper+lower-0.002,max(abs(upper-lower)+0.002,length(wanted-shoulder)))
                    let along=(upper*upper-lower*lower+distance*distance)/(2*distance)
                    let pole=restElbow-shoulder
                    let bend=normalize(pole-direction*dot(pole,direction))
                    gestureElbows[elbow]=shoulder+direction*along+bend*sqrt(max(0,upper*upper-along*along))
                    gestureWrists[elbow]=shoulder+direction*distance
                }
                if i==22 || i==39 { result=aim(i==22 ? 23:40,restingUpper) }
                if i==23 || i==40 { result=aim(i==23 ? 24:41,restingForearm) }
                if i==26 || i==42 { result=handFrame(i==26 ? 30:46,[-side,0.04,0.08],[0,-0.35,-1]) }
                var curl:Float=0
                if [27,30,33,43,46,49].contains(i) { curl=0.30 }
                if [28,31,34,44,47,50].contains(i) { curl=0.85 }
                if [29,32,35,45,48,51].contains(i) { curl=0.35 }
                if curl>0 {
                    let p=inherited.columns.3
                    result=translation([p.x,p.y,p.z])*rotate(-side*curl,[0,1,0])*translation([-p.x,-p.y,-p.z])*inherited
                }
                if i==36 || i==52 {
                    let p=inherited.columns.3
                    result=translation([p.x,p.y,p.z])*rotate(side*0.40,[0,0,1])*translation([-p.x,-p.y,-p.z])*inherited
                }
                if let pose=arms[side] {
                    let restPose=ArmPose.rest(side),de=pose.elbow-restPose.elbow,dw=pose.wrist-restPose.wrist
                    if i==22 || i==39 { let child=i==22 ? 23:40;result=aim(child,gestureElbows[child].map { $0-xyz(inherited) } ?? (restingUpper+de*1.5)) }
                    if i==23 || i==40 { result=aim(i==23 ? 24:41,gestureWrists[i].map { $0-xyz(inherited) } ?? (restingForearm+(dw-de)*2)) }
                    if i==26 || i==42 {
                        let p=xyz(inherited),turn=pose.angle-restPose.angle
                        let direction=SIMD3<Float>(-side,0.04,0.08)
                        result=translation(p)*rotate(turn,[0,0,1])*rotate(pose.palmTurn,normalize(direction))*translation(-p)*handFrame(i==26 ? 30:46,direction,[0,-0.35,-1])
                        if action == .dance { result=blendRotation(result,handFrame(i==26 ? 30:46,[side,0.25,0.05],[0,0,1]),actionEnvelope) }
                        if action == .think && side>0 { result=blendRotation(result,handFrame(46,[-1,0.10,0],[0,0,-1]),actionEnvelope) }
                        if action == .shrug { result=blendRotation(handFrame(i==26 ? 30:46,[-side,0.04,0.08],[0,-0.35,-1]),handFrame(i==26 ? 30:46,[side,0.08,0],[0,1,0.1]),pose.spread) }
                        if action == .clap { result=blendRotation(result,handFrame(i==26 ? 30:46,[-side,0,0],[0,side<0 ? 1:-1,0]),min(1,(length(dw)+length(de))*6)) }
                    }
                    if (27...38).contains(i) || (43...54).contains(i) { result=blendRotation(result,inherited,pose.spread) }
                    if action == .think && [52,53,54].contains(i) {
                        let p=xyz(inherited)
                        let axis:SIMD3<Float>=[0,-1,0]
                        result=blendRotation(result,translation(p)*rotate(i==52 ? 0.8:0.7,axis)*translation(-p)*inherited,actionEnvelope)
                    }
                    if action == .think && side>0 && [43,44,45,46,47,48,49,50,51].contains(i) {
                        let angle:Float=[43,46,49].contains(i) ? 1.4:[44,47,50].contains(i) ? 1.8:0.9
                        let p=xyz(inherited)
                        let axis=SIMD3<Float>(0,-1,0)
                        result=blendRotation(result,translation(p)*rotate(angle,axis)*translation(-p)*inherited,actionEnvelope)
                    }

                }
                if wave>0 {
                    if i==39 { result=blendRotation(result,aim(40,[0.85,0.53,0.02]),wave) }
                    if i==40 { result=blendRotation(result,aim(41,[0.30,0.95,0.10]),wave) }
                    if i==42 {
                        let p=xyz(inherited)
                        let swing=waveSwingEnabled ? 0.28*sin(wt*8):0
                        let target=translation(p)*rotate(swing,[0,0,1])*rotate(-Float.pi/2,[0,1,0])*translation(-p)*aim(46,[0,1,0])
                        result=blendRotation(result,target,wave)
                    }
                    if (43...54).contains(i) { result=blendRotation(result,inherited,wave) }
                }
            }
            posed.append(result)
        }
        if !sourcePose && transitionPose.count==posed.count {
            let amount=ease(Float((time-transitionStarted)/0.20))
            if amount<1 {
                let target=posed
                for (i,node) in source.nodes.enumerated() {
                    let from=node.parent<0 ? transitionPose[i]:transitionPose[node.parent].inverse*transitionPose[i]
                    let to=node.parent<0 ? target[i]:target[node.parent].inverse*target[i]
                    // Blend local joint rotations, not skin matrices, to retain coherent limbs.
                    func components(_ m:simd_float4x4)->(simd_quatf,simd_float3x3) {
                        let c=simd_float3x3(columns:(SIMD3(m.columns.0.x,m.columns.0.y,m.columns.0.z),SIMD3(m.columns.1.x,m.columns.1.y,m.columns.1.z),SIMD3(m.columns.2.x,m.columns.2.y,m.columns.2.z)))
                        // Polar decomposition preserves inherited shear as well as scale.
                        var rotation=c*(1/max(length(c.columns.0),max(length(c.columns.1),length(c.columns.2))))
                        for _ in 0..<6 { rotation=(rotation+rotation.inverse.transpose)*0.5 }
                        return (simd_quatf(rotation),rotation.transpose*c)
                    }
                    let (qa,sa)=components(from),(qb,sb)=components(to)
                    let stretch=sa+(sb-sa)*amount
                    let stretch4=simd_float4x4(columns:(SIMD4(stretch.columns.0,0),SIMD4(stretch.columns.1,0),SIMD4(stretch.columns.2,0),SIMD4(0,0,0,1)))
                    let blended=translation(xyz(from)+(xyz(to)-xyz(from))*amount)*simd_float4x4(simd_slerp(qa,qb,amount))*stretch4
                    posed[i]=node.parent<0 ? blended:posed[node.parent]*blended
                }
            } else { transitionPose.removeAll(keepingCapacity:true) }
        }
        displayedPose=posed
        let grounding=translation(SIMD3<Float>(0,sourcePose ? 0 : -0.02,0))
        return posed.enumerated().map { i,m in Instance(model:camera*grounding*m*inverseRest[i],color:[1,1,1,1]) }
    }
}
private func scaleMatrix(_ s:SIMD3<Float>)->simd_float4x4 {
    simd_float4x4(columns:(SIMD4(s.x,0,0,0),SIMD4(0,s.y,0,0),SIMD4(0,0,s.z,0),SIMD4(0,0,0,1)))
}
struct FanMeshData {
    let vertices:Data
    let indices:Data
    let indexCount:Int
    init(url:URL) throws {
        let data=try Data(contentsOf:url)
        guard data.count>=20 else { throw failure("Truncated fan mesh") }
        let h=(0..<5).map { i in data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset:i*4,as:UInt32.self) } }
        let count=Int(h[2]),indices=Int(h[3])
        guard h[0]==0x424F4E5A,h[1]==4,h[4]==128,count>0,indices%3==0,data.count==20+count*128+indices*4 else { throw failure("Invalid fan mesh") }
        self.vertices=data.subdata(in:20..<(20+count*128));self.indices=data.subdata(in:(20+count*128)..<data.count);indexCount=indices
        for i in 0..<indices {
            let v=self.indices.withUnsafeBytes { $0.loadUnaligned(fromByteOffset:i*4,as:UInt32.self) }
            guard v<count else { throw failure("Invalid fan mesh index") }
        }
    }
}
