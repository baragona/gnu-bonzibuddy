import Foundation
import simd

func validateRoutines() throws {
    func finite(_ v:SIMD3<Float>)->Bool {v.x.isFinite && v.y.isFinite && v.z.isFinite}
    func matrixError(_ a:simd_float4x4,_ b:simd_float4x4)->Float {
        (0..<4).reduce(Float(0)) {largest,c in (0..<4).reduce(largest) {max($0,abs(a[c][$1]-b[c][$1]))}}
    }
    func validAnchor(_ anchor:PropAnchor)->Bool {
        switch anchor {
        case .character,.stage,.attachment: return true
        case let .transformed(parent,offset,rotation): return validAnchor(parent) && finite(offset) && abs(length(rotation.vector)-1)<0.001
        case let .blend(from,to,weight): return validAnchor(from) && validAnchor(to) && weight.isFinite && (0...1).contains(weight)
        }
    }
    var playback=ActionPlayback()
    playback.play(.banana,at:5)
    let middle=playback.sample(at:7),finished=playback.sample(at:20),rewound=playback.sample(at:7)
    guard middle.action == .banana,finished.action == .idle,finished.started == 5+Action.banana.duration,rewound.action == middle.action,rewound.elapsed == middle.elapsed else {throw failure("Playback sampling mutated its selected clip")}
    var sampled=0,propSamples=0
    for (action,definition) in RoutineLibrary.definitions {
        guard definition.duration.isFinite,definition.duration>0 else {throw failure("Invalid routine duration")}
        if let continuation=definition.continuation {
            guard continuation.entryElapsed>=0,continuation.entryElapsed<definition.duration,
                  continuation.acceptsFrom.lowerBound>=0,continuation.acceptsFrom.upperBound<=definition.duration else {throw failure("Invalid continuation range")}
            for frame in 0...Int(definition.duration*120) {
                let t=Double(frame)/120,delay=continuation.delay(t)
                if let exit=continuation.exitElapsed(t) {
                    guard exit.isFinite,exit>=0,exit<definition.duration else {throw failure("Invalid continuation exit phase")}
                }
                guard delay.isFinite,delay>=0,delay<=definition.duration else {throw failure("Invalid continuation delay")}
            }
        }
        if let loop=definition.holdRange {
            guard loop.lowerBound>=0,loop.upperBound<definition.duration,loop.upperBound>loop.lowerBound else {throw failure("Invalid hold range")}
            let a=definition.sample(loop.lowerBound),b=definition.sample(loop.upperBound)
            guard a.face.distance(to:b.face)<0.0001,abs(a.headYaw-b.headYaw)<0.0001,a.props.map(\.id)==b.props.map(\.id) else {throw failure("Discontinuous hold-loop channels")}
        }
        for t in [-0.1,0,definition.duration,definition.duration+0.1] {
            let pose=RoutineLibrary.sample(action,at:t)
            guard pose.props.isEmpty,pose.face.distance(to:FacialIntent())<0.0001,pose.hands.values.allSatisfy({$0.weight<0.0001}),length(pose.stance.pelvisOffset)<0.0001,pose.stance.feet.values.allSatisfy({$0.weight<0.0001}) else {throw failure("Routine leaks beyond entry/return: \(action)")}
        }
        for frame in 0...Int(ceil(definition.duration*120)) {
            let elapsed=Double(frame)/120
            let delay=definition.returnDelay(elapsed)
            guard delay.isFinite,delay>=0,delay<=definition.duration else {throw failure("Invalid return delay")}
            let pose=RoutineLibrary.sample(action,at:elapsed)
            sampled += 1
            guard [pose.bodyYaw,pose.headYaw,pose.headTilt,pose.headPitch,pose.face.jawOpening,pose.face.eyeClosure,pose.face.smileOffset,pose.face.gaze.x,pose.face.gaze.y].allSatisfy(\.isFinite),
                  (0...1).contains(pose.face.jawOpening),(0...1).contains(pose.face.eyeClosure) else {throw failure("Invalid facial or body channels: \(action)")}
            guard finite(pose.stance.pelvisOffset) else {throw failure("Invalid pelvis target")}
            for foot in pose.stance.feet.values {
                guard finite(foot.ankle),finite(foot.kneeBend),length(foot.kneeBend)>0.001,(0...1).contains(foot.weight),abs(length(foot.rotation.vector)-1)<0.001 else {throw failure("Invalid foot target")}
            }
            for hand in pose.hands.values {
                guard hand.palmContact.map(finite) ?? true,finite(hand.wrist),finite(hand.fingers),finite(hand.palm),length(cross(hand.fingers,hand.palm))>0.001,(0...1).contains(hand.weight),(0...1).contains(hand.grip),(0...1).contains(hand.fist) else {throw failure("Invalid hand frame: \(action)")}
            }
            guard Set(pose.props.map(\.id)).count==pose.props.count else {throw failure("Duplicate prop IDs")}
            for prop in pose.props {
                propSamples += 1
                guard validAnchor(prop.anchor),finite(prop.offset),finite(prop.scale),prop.scale.min()>0,(0...1).contains(prop.visibility),prop.rotation.vector.x.isFinite,abs(length(prop.rotation.vector)-1)<0.001 else {throw failure("Invalid prop transform")}
                switch (prop.kind,prop.deformation) {
                case (.letterBack,.rigid),(.letterFlap,.rigid),(.mailbox,.rigid),(.mailboxDoor,.rigid),(.writingPad,.rigid),(.pencil,.rigid),(.globe,.rigid),(.coconut,.rigid),(.sunglasses,.rigid),(.headphones,.rigid),(.butterflyWing,.rigid),(.butterflyBody,.rigid),(.bookLeft,.rigid),(.bookRight,.rigid): break
                case let (.bookLeaf,.page(curl)):
                    guard curl.isFinite,(0...1).contains(curl) else {throw failure("Invalid page curl")}
                case let (.bananaFruit,.fruit(remaining)):
                    guard remaining.isFinite,(0...1).contains(remaining) else {throw failure("Invalid fruit amount")}
                case let (.bananaPeel,.peel(openings)):
                    guard finite(openings),openings.min()>=0,openings.max()<=1 else {throw failure("Invalid peel channels")}
                default: throw failure("Prop deformation does not match mesh")
                }
            }
        }
    }
    var vertexCount=0
    for kind in [PropKind.bananaFruit,.bananaPeel] {
        let (vertices,indices)=BananaGeometry.mesh(kind)
        guard !vertices.isEmpty,indices.count%3==0,indices.allSatisfy({Int($0)<vertices.count}) else {throw failure("Invalid banana topology")}
        for v in vertices {
            guard [v.position,v.normal,v.openedPosition,v.openedNormal,v.uv].allSatisfy({p in (0..<4).allSatisfy({p[$0].isFinite})}) else {throw failure("Nonfinite banana mesh")}
        }
        vertexCount += vertices.count
    }
    let rig=try FanRig(url:URL(fileURLWithPath:"Resources/FanModel/FanRig.json"))
    rig.updateLiveAction(.lookLeft,started:0,at:0.8)
    let front=rig.instances(yaw:0,pitch:0,at:0.8),quarter=rig.instances(yaw:-0.7,pitch:0.15,at:0.8)
    let cameraChange=quarter[0].model*front[0].model.inverse
    var attachmentError:Float=0,rigidityError:Float=0
    for attachment in [RigAttachment.head,.wrist(.left),.wrist(.right),.indexTip(.left),.indexTip(.right)] {
        for axes in [AttachmentAxes.character,.joint] {
            let a=rig.attachmentFrame(attachment,axes:axes,bones:front),b=rig.attachmentFrame(attachment,axes:axes,bones:quarter)
            attachmentError=max(attachmentError,matrixError(cameraChange*a,b))
            for i in 0..<3 {for j in 0..<3 {
                rigidityError=max(rigidityError,abs(dot(a[i],a[j])-(i==j ? 1:0)))
            }}
        }
    }
    let motion=PropMotion()
    let cues=[PropCue(id:"attachment.fixture",kind:.globe,anchor:.attachment(.head,axes:.joint),offset:[0,0.1,0.2],scale:SIMD3(repeating:0.1))]
    _=rig.instances(yaw:0,pitch:0,at:0.8)
    let before=motion.sample(action:.globe,started:0,at:0.8,cues:cues,rig:rig,bones:front)
    _=motion.sample(action:.wave,started:0.8,at:0.8,cues:[],rig:rig,bones:front)
    _=rig.instances(yaw:-0.7,pitch:0.15,at:0.8)
    let turned=motion.sample(action:.wave,started:0.8,at:0.8,cues:[],rig:rig,bones:quarter)
    guard before.count==1,turned.count==1 else {throw failure("Interrupted attachment disappeared")}
    let retiringCameraError=matrixError(cameraChange*before[0].model,turned[0].model)
    guard attachmentError<0.0001,rigidityError<0.0001,retiringCameraError<0.0001 else {throw failure("Attachment frame or retiring camera invariance failed")}
    let report:[String:Any]=["playbackSeekPassed":true,"registeredRoutines":RoutineLibrary.definitions.count,"sampledFrames":sampled,"propSamples":propSamples,"bananaVertices":vertexCount,"maximumAttachmentCameraError":attachmentError,"maximumAttachmentRigidityError":rigidityError,"retiringPropCameraError":retiringCameraError,"note":"Routine channel/lifecycle contracts, semantic attachment frames, topology and camera invariance. Does not establish original visual fidelity or comprehensive collision avoidance."]
    try FileManager.default.createDirectory(atPath:"Validation/Routines",withIntermediateDirectories:true)
    let data=try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]);try data.write(to:URL(fileURLWithPath:"Validation/Routines/checks.json"));print(String(decoding:data,as:UTF8.self))
}
