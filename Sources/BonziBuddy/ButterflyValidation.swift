import Foundation
import MetalKit
import simd

func validateButterfly() throws {
    var vertexCount=0,triangleCount=0
    for kind in [PropKind.butterflyBody,.butterflyWing] {
        let (vertices,indices)=ButterflyGeometry.mesh(kind)
        guard indices.count%3==0,indices.allSatisfy({Int($0)<vertices.count}) else {throw failure("Invalid butterfly topology")}
        for i in stride(from:0,to:indices.count,by:3) {
            let v=(0..<3).map {vertices[Int(indices[i+$0])]}
            let p=v.map {SIMD3($0.position.x,$0.position.y,$0.position.z)}
            let n=v[0].normal+v[1].normal+v[2].normal,normal=cross(p[1]-p[0],p[2]-p[0])
            guard length(normal)>1e-12,dot(normal,SIMD3(n.x,n.y,n.z))>0 else {throw failure("Invalid butterfly winding")}
        }
        vertexCount+=vertices.count;triangleCount+=indices.count/3
    }
    var maximumVelocitySeam:Float=0
    let path=ButterflyRoutine.flight,h=0.0001
    for key in path.keys.dropFirst().dropLast() {
        let before=(path.sample(at:key.0)-path.sample(at:key.0-h))/Float(h)
        let after=(path.sample(at:key.0+h)-path.sample(at:key.0))/Float(h)
        maximumVelocitySeam=max(maximumVelocitySeam,length(after-before))
    }
    guard maximumVelocitySeam<0.02 else {throw failure("Flight path stops or jumps at waypoints")}
    let rig=try FanRig(url:URL(fileURLWithPath:"Resources/FanModel/FanRig.json")),motion=PropMotion()
    var landingError:Float=0,touchDistance:Float=0,pointingClearance:Float=0
    for frame in 0...Int(ButterflyRoutine.duration*120) {
        let t=Double(frame)/120
        rig.updateLiveAction(.butterfly,started:0,at:t,elapsed:t)
        let bones=rig.instances(yaw:0,pitch:0,at:t)
        let draws=motion.sample(action:.butterfly,started:0,at:t,cues:rig.routine.props,rig:rig,bones:bones)
        if t>=1.7 && t<=7.8 {
            guard draws.count==3,let body=draws.first(where:{$0.id=="butterfly.body"}) else {throw failure("Missing butterfly articulation")}
            let tip=rig.attachmentFrame(.indexTip(.left),axes:.character,bones:bones)
            let expected=tip*SIMD4<Float>(0,0.075,0,1)
            landingError=max(landingError,length(body.model.columns.3-expected))
            if t>=4 && t<=6 {
                let right=rig.attachmentFrame(.indexTip(.right),axes:.character,bones:bones)
                touchDistance=max(touchDistance,length(right.columns.3-tip.columns.3))
            }
            if frame==360 {
                let index=(bones[0].model.inverse*tip).columns.3
                let middle=bones[0].model.inverse*bones[32].model*rig.rest[32].columns.3
                pointingClearance=index.y-middle.y
            }
        }
    }
    guard landingError<0.00001,pointingClearance>0.10 else {throw failure("Butterfly perch or pointing hand failed")}
    let report:[String:Any]=["vertices":vertexCount,"maximumWaypointVelocityMismatch":maximumVelocitySeam,"triangles":triangleCount,"maximumPerchAttachmentError":landingError,"maximumTouchTipDistance":touchDistance,"indexAboveCurledMiddle":pointingClearance,"note":"Perch uses a terminal-joint marker calibrated to distal mesh samples. Does not prove exact surface contact or collision avoidance. Touch distance remains a diagnostic during choreography refinement."]
    try FileManager.default.createDirectory(atPath:"Validation/Butterfly",withIntermediateDirectories:true)
    let data=try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys])
    try data.write(to:URL(fileURLWithPath:"Validation/Butterfly/checks.json"));print(String(decoding:data,as:UTF8.self))
}


func validateButterflyMaterials() throws {
    guard let device=MTLCreateSystemDefaultDevice() else {throw failure("Metal unavailable")}
    let renderer=try Renderer(device:device,previewMesh:URL(fileURLWithPath:"Resources/FanModel/FanRigged.mesh"),rigURL:URL(fileURLWithPath:"Resources/FanModel/FanRig.json"))
    renderer.fanLiveActions=true;renderer.fanTeethEnabled=true;renderer.fanAutoBlink=false;renderer.shadowsEnabled=false
    renderer.character.play(.butterfly,at:0)
    _=try renderer.offscreen(width:800,height:640,at:0)
    let (open,_)=try renderer.offscreen(width:800,height:640,at:2.5)
    func bytes(_ texture:MTLTexture)->[UInt8] {
        var result=[UInt8](repeating:0,count:800*640*4)
        texture.getBytes(&result,bytesPerRow:800*4,from:MTLRegionMake2D(0,0,800,640),mipmapLevel:0)
        return result
    }
    let before=bytes(open)
    let rig=renderer.fanRig!,bones=rig.instances(yaw:0,pitch:0.18,at:2.5)
    let draws=PropMotion().sample(action:.butterfly,started:0,at:2.5,cues:rig.routine.props,rig:rig,bones:bones)
    var lower=SIMD2<Float>(repeating:Float.infinity),upper=SIMD2<Float>(repeating:-Float.infinity)
    for draw in draws {
        for vertex in ButterflyGeometry.mesh(draw.kind).0 {
            let p=renderer.projection(width:800,height:640)*draw.model*vertex.position
            let pixel=SIMD2<Float>((p.x/p.w+1)*400,(1-p.y/p.w)*320)
            lower=simd_min(lower,pixel);upper=simd_max(upper,pixel)
        }
    }
    renderer.fanEyeClosure=1;renderer.fanGaze=[0.8,-0.8]
    let (closed,_)=try renderer.offscreen(width:800,height:640,at:2.5),after=bytes(closed)
    let x0=max(0,Int(floor(lower.x))),x1=min(799,Int(ceil(upper.x))),y0=max(0,Int(floor(lower.y))),y1=min(639,Int(ceil(upper.y)))
    var goldPixels=0
    for y in y0...y1 {for x in x0...x1 {
        let i=(y*800+x)*4
        if before[i+3]>128 && before[i+2]>100 && before[i+1]>80 && Int(before[i])*2<Int(before[i+2]) {goldPixels+=1}
    }}
    guard goldPixels>40 else {throw failure("Material check did not capture the butterfly wings")}
    var maximum=0,changed=0
    for y in y0...y1 {for x in x0...x1 {for c in 0..<4 {
        let i=(y*800+x)*4+c,difference=abs(Int(before[i])-Int(after[i]))
        maximum=max(maximum,difference);if difference>0 {changed+=1}
    }}}
    guard maximum==0 else {throw failure("Facial controls altered prop color: maximum byte difference \(maximum)")}
    let report:[String:Any]=["propBounds":[x0,y0,x1,y1],"goldPixels":goldPixels,"maximumByteDifference":maximum,"changedChannels":changed,"note":"Same-time butterfly crop with shadows disabled, eyes open versus closed and gaze changed. Facial inputs must not enter prop materials."]
    try FileManager.default.createDirectory(atPath:"Validation/Butterfly",withIntermediateDirectories:true)
    let data=try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys])
    try data.write(to:URL(fileURLWithPath:"Validation/Butterfly/material-isolation.json"));print(String(decoding:data,as:UTF8.self))
}
