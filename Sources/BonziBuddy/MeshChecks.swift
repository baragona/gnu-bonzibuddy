import Foundation
import simd

func checkMesh() throws {
    let mesh = try PolygonMesh.load(from:URL(fileURLWithPath:"Resources/Bonzi.mesh"))
    let character = Character(), count = character.instances(at:0).count
    for vertex in mesh.vertices {
        for v in [vertex.position0,vertex.position1,vertex.normal0,vertex.normal1,vertex.color,vertex.skin] {
            guard (0..<4).allSatisfy({ v[$0].isFinite }) else { throw failure("Nonfinite mesh attribute") }
        }
        guard vertex.skin.x >= 0, vertex.skin.y >= 0, vertex.skin.x < Float(count), vertex.skin.y < Float(count), (vertex.skin.z == -2 || vertex.skin.z == -1 || vertex.skin.z >= 0), vertex.skin.z <= 1, vertex.skin.w >= 0, vertex.skin.w <= 1 else { throw failure("Invalid bone influence") }
    }
    for vertex in mesh.vertices where vertex.skin.z == -1 {
        guard character.armBones.contains(Int(vertex.skin.x)), character.armBones.contains(Int(vertex.skin.y)), character.palmBones.contains(Int(vertex.skin.y)+1), vertex.position0.x >= 0, vertex.position0.x <= 1, vertex.position0.w >= 0 else { throw failure("Invalid arm spline vertex") }
    }
    for vertex in mesh.vertices where vertex.skin.z == -2 {
        guard character.surfaces[Int(vertex.skin.x)] == .lid, vertex.position0.x >= 0, vertex.position0.x <= 1, vertex.position0.y >= 0, vertex.position0.y <= 1 else { throw failure("Invalid eyelid patch") }
    }
    var edges: [UInt64:Int] = [:]
    for i in stride(from:0,to:mesh.indices.count,by:3) {
        let t = [mesh.indices[i],mesh.indices[i+1],mesh.indices[i+2]]
        for j in 0..<3 {
            let a = t[j], b = t[(j+1)%3]
            let key = UInt64(min(a,b))<<32 | UInt64(max(a,b))
            edges[key,default:0] += 1
        }
    }
    let boundaryEdges = edges.values.filter { $0 == 1 }.count
    let nonmanifoldEdges = edges.values.filter { $0 > 2 }.count
    guard boundaryEdges == 0, nonmanifoldEdges == 0 else { throw failure("Mesh contains open or nonmanifold edges") }
    var sampledFrames = 0, maximumInterruptionError:Float = 0
    for (i,action) in Action.allCases.enumerated() {
        let start = Double(i)*1.137
        let before = character.instances(at:start)
        let mouthBefore = character.mouthOpening
        character.play(action,at:start)
        let after = character.instances(at:start)
        guard abs(mouthBefore-character.mouthOpening) < 0.0001 else { throw failure("Jaw morph snaps at action interruption") }
        guard before.count == after.count, after.count == count else { throw failure("Rig layout changed across an action") }
        for j in before.indices { for column in 0..<4 { maximumInterruptionError = max(maximumInterruptionError,length(before[j].model[column]-after[j].model[column])) } }
        for frame in 0..<120 {
            let pose = character.instances(at:start+Double(frame)/120)
            guard pose.count == count else { throw failure("Rig topology changed during animation") }
            for bone in pose {
                guard (0..<4).allSatisfy({ c in (0..<4).allSatisfy { r in bone.model[c][r].isFinite } }), abs(simd_determinant(bone.model)) > 1e-9 else { throw failure("Invalid animated bone transform") }
            }
            sampledFrames += 1
        }
    }
    guard maximumInterruptionError < 0.0001 else { throw failure("Action interruption snaps the rig: \(maximumInterruptionError)") }
    let face = Character(); face.play(.speak,at:0)
    _ = face.instances(at:0); let closed = face.mouthOpening
    _ = face.instances(at:0.46); let opened = face.mouthOpening
    guard closed < 0.001, opened > 0.06 else { throw failure("Speech jaw does not animate") }
    for frame in 0...10 {
        let t=Double(frame)/ShrugAnimation.referenceFPS
        for side:Float in [-1,1] {
            let forward=ShrugAnimation.arm(at:t,side:side)
            let reverse=ShrugAnimation.arm(at:ShrugAnimation.returnStart+Double(10-frame)/15,side:side)
            guard length(forward.wrist-reverse.wrist)<0.0001, length(forward.elbow-reverse.elbow)<0.0001 else { throw failure("Shrug return does not retrace the source poses") }
            let before=ShrugAnimation.arm(at:max(0,t-0.00001),side:side),after=ShrugAnimation.arm(at:t+0.00001,side:side)
            guard length(before.wrist-after.wrist)<0.001 else { throw failure("Shrug keyframe discontinuity") }
        }
    }
    guard ShrugAnimation.referenceFrame(at:ShrugAnimation.duration)==0 else { throw failure("Shrug does not return to idle") }
    for side:Float in [-1,1] {
        let rest=ArmPose.rest(side), end=ClapAnimation.arm(at:ClapAnimation.duration,side:side)
        guard length(rest.wrist-end.wrist)<0.0001, length(rest.elbow-end.elbow)<0.0001 else { throw failure("Clap fails to return to rest") }
        for key in 1..<ClapAnimation.frames.count-1 {
            let time=Double(key)/ClapAnimation.fps
            let before=ClapAnimation.arm(at:time-0.00001,side:side),after=ClapAnimation.arm(at:time+0.00001,side:side)
            guard length(before.wrist-after.wrist)<0.001 else { throw failure("Clap keyframe discontinuity") }
        }
    }
    let waving=Character(); waving.play(.wave,at:0)
    let firstWave=waving.instances(at:0.5)
    let forearm=waving.armBones[3],palm=waving.palmBones[1]
    func bodyFrame(_ m:simd_float4x4)->simd_float4x4 {
        var rigid=m
        for c in 0..<3 { rigid[c] /= length(SIMD3(m[c].x,m[c].y,m[c].z)) }
        return rigid
    }
    let initialArm=bodyFrame(firstWave[0].model).inverse*firstWave[forearm].model
    let initialPalm=bodyFrame(firstWave[0].model).inverse*firstWave[palm].model
    var wristDrift:Float=0,handRotationChange:Float=0
    for frame in 0..<360 {
        let pose=waving.instances(at:0.5+Double(frame)/120)
        let arm=bodyFrame(pose[0].model).inverse*pose[forearm].model
        let hand=bodyFrame(pose[0].model).inverse*pose[palm].model
        for column in 0..<4 { wristDrift=max(wristDrift,length(arm[column]-initialArm[column])) }
        handRotationChange=max(handRotationChange,length(hand.columns.1-initialPalm.columns.1))
    }
    guard wristDrift<0.0001,handRotationChange>0.05 else { throw failure("Wave must rotate the hand while holding the wrist steady") }
    let breathing=Character(), resting=breathing.instances(at:0)
    let feet=breathing.footBones
    var footDrift:Float=0,bodyMotion:Float=0,bodyExpansion:Float=0
    for frame in 0..<600 {
        let pose=breathing.instances(at:Double(frame)/120)
        for foot in feet { for column in 0..<4 { footDrift=max(footDrift,length(pose[foot].model[column]-resting[foot].model[column])) } }
        bodyExpansion=max(bodyExpansion,abs(length(pose[0].model.columns.0)-length(resting[0].model.columns.0)))
        bodyMotion=max(bodyMotion,length(pose[0].model.columns.3-resting[0].model.columns.3))
    }
    guard feet.count==10,footDrift<0.00001,bodyMotion>0.003,bodyExpansion>0.002 else { throw failure("Idle must breathe with grounded feet") }
    guard BlinkAnimation.eyeOpen(at:4.1)==0, BlinkAnimation.eyeOpen(at:4.3)>0.999 else { throw failure("Blink fails to close and reopen") }
    for left in [false,true] {
        guard LookAnimation.yaw(at:LookAnimation.duration,left:left)==0 else { throw failure("Glance fails to return to center") }
        for key in 1..<LookAnimation.frames.count-1 {
            let t=Double(key)/15
            guard abs(LookAnimation.yaw(at:t-0.00001,left:left)-LookAnimation.yaw(at:t+0.00001,left:left))<0.001 else { throw failure("Glance snaps at a keyframe") }
        }
    }
    let neutral=Character(),camera=Character()
    neutral.pitch=0;camera.pitch=0.3;camera.yaw=0.7
    neutral.play(.wave,at:0);camera.play(.wave,at:0)
    var cameraPoseError:Float=0
    for frame in 0..<60 {
        let time=Double(frame)/120
        if frame==12 { neutral.play(.dance,at:time);camera.play(.dance,at:time) }
        camera.yaw=0.7+Float(frame)*0.01
        let a=neutral.instances(at:time),b=camera.instances(at:time)
        let orientation=rotate(camera.pitch,[1,0,0])*rotate(camera.yaw,[0,1,0])
        for i in a.indices { for c in 0..<4 { cameraPoseError=max(cameraPoseError,length((orientation*a[i].model)[c]-b[i].model[c])) } }
    }
    guard cameraPoseError<0.0001 else { throw failure("Camera rotation changes the blended pose") }
    let report:[String:Any] = ["passed":true,"cameraPoseError":cameraPoseError,"idleFootDrift":footDrift,"idleBodyMotion":bodyMotion,"idleBodyExpansion":bodyExpansion,"waveForearmDrift":wristDrift,"waveHandRotationChange":handRotationChange,"sampledFrames":sampledFrames,"vertexCount":mesh.vertices.count,"boneCount":count,"boundaryEdges":boundaryEdges,"nonmanifoldEdges":nonmanifoldEdges,"maximumInterruptionMatrixError":maximumInterruptionError,"checks":["Binary mesh bounds and index validity","Closed two-manifold triangle surfaces","Finite attributes and valid skin influences", "Valid articulated arm ring parameters","Stable rig layout across all actions","Nonsingular animated transforms","Continuous pose and jaw morph at action interruption","Speech opens the jaw from a closed resting pose","Shrug interpolation is continuous and reverses the source poses", "Clap keyframes are continuous and return to rest", "Wave forearm stays fixed while the hand rotates", "Idle feet stay grounded across 600 breathing samples", "Blink closes and reopens", "Glance keyframes are continuous and return to center", "Camera changes preserve pose through interrupted transitions"]]
    let data = try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys])
    try data.write(to:URL(fileURLWithPath:"Validation/mesh-checks.json")); print(String(decoding:data,as:UTF8.self))
}
