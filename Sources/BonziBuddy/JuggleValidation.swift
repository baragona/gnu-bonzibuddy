import Foundation
import simd

func validateJuggle() throws {
    let rig=try FanRig(url:URL(fileURLWithPath:"Resources/FanModel/FanRig.json"))
    let motion=PropMotion()
    var maxHandoffJump:Float=0,minSeparation:Float=100
    var previous:[String:SIMD3<Float>]=[:]
    var previousTime:[String:Double]=[:]
    let dt=0.00001
    // Inspect both sides of every release/catch in the intended timeline.
    var times=[Double(0)]
    for ball in 0..<3 { for cycle in 0...3 {
        let release=CoconutJuggle.firstRelease+Double(ball)*CoconutJuggle.cadence+Double(cycle)*CoconutJuggle.period
        for t in [release,release+CoconutJuggle.flight] {times += [t-dt,t,t+dt]}
    }}
    for t in times.sorted() {
        rig.updateLiveAction(.juggle,started:0,at:t)
        let bones=rig.instances(yaw:0,pitch:0,at:t)
        let draws=motion.sample(action:.juggle,started:0,at:t,cues:rig.routine.props,rig:rig,bones:bones)
        for d in draws {
            let p=SIMD3(d.model.columns.3.x,d.model.columns.3.y,d.model.columns.3.z)
            guard p.x.isFinite,p.y.isFinite,p.z.isFinite else {throw failure("Nonfinite coconut pose")}
            if let last=previous[d.id],t>0 {
                // Larger gaps between sampled events are intentional flight motion.
                if let lastTime=previousTime[d.id],t-lastTime<dt*1.1 {maxHandoffJump=max(maxHandoffJump,length(p-last))}
            }
            previous[d.id]=p;previousTime[d.id]=t
        }
    }
    let mesh=try FanMeshData(url:URL(fileURLWithPath:"Resources/FanModel/FanRigged.mesh"))
    let morph=try Data(contentsOf:URL(fileURLWithPath:"Resources/FanModel/FanMorphs.bin"))
    let count=mesh.vertices.count/128
    var head:[SIMD4<Float>]=[]
    for i in stride(from:0,to:count,by:8) {
        let v=(0..<32).map { c in mesh.vertices.withUnsafeBytes { $0.loadUnaligned(fromByteOffset:i*128+c*4,as:Float.self) } }
        let weight=(0..<8).filter {Int(v[16+$0])==56}.reduce(Float(0)) {$0+v[24+$1]}
        if weight<0.999 {continue}
        var p=SIMD4<Float>(v[0],v[1],v[2],1)
        for (target,amount) in [(0,Float(0.2)),(2,Float(1))] {
            for c in 0..<3 {p[c] += morph.withUnsafeBytes { $0.loadUnaligned(fromByteOffset:16+(target*count+i)*32+c*4,as:Float.self) }*amount}
        }
        if p.y>0.48 && p.y<1.25 {
            let x=p.y<0.68 ? (p.y-0.48)/0.20:p.y>0.90 ? (1.25-p.y)/0.35:1
            p.y += 0.10*x*x*(3-2*x)
        }
        head.append(p)
    }
    guard head.count>100 else {throw failure("Insufficient head surface samples")}
    var minHeadClearance:Float=100, minAllSeparation:Float=100
    var worstHeadTime=0.0
    let pairMotion=PropMotion()
    for frame in 0...Int(CoconutJuggle.duration*120) {
        let t=Double(frame)/120
        let cues=CoconutJuggle.sample(at:t).props
        do {
            rig.updateLiveAction(.juggle,started:0,at:t)
            let bones=rig.instances(yaw:0,pitch:0,at:t)
            let draws=pairMotion.sample(action:.juggle,started:0,at:t,cues:cues,rig:rig,bones:bones)
            if t>=0.65 && t<=5.95 {
                for i in draws.indices {for j in draws.indices where j>i {
                    minAllSeparation=min(minAllSeparation,length(draws[i].model.columns.3-draws[j].model.columns.3))
                }}
            }
            for cue in cues {
                if case .character=cue.anchor {
                    let center=bones[0].model*SIMD4(cue.offset,1)
                    for p in head {
                        let clearance=length(center-bones[56].model*p)-CoconutJuggle.radius*1.12
                        if clearance<minHeadClearance {minHeadClearance=clearance;worstHeadTime=t}
                    }
                }
            }
        }
        if t>1.8 && t<5.4 {
            // Airborne coconuts must not pass through one another.
            let airborne=cues.filter {if case .character=$0.anchor {return true};return false}
            for i in airborne.indices {for j in airborne.indices where j>i {minSeparation=min(minSeparation,length(airborne[i].offset-airborne[j].offset))}}
        }
    }
    var velocityMismatch:Float=0
    let epsilon=0.0001
    for ball in 0..<3 {for cycle in 0...3 {
        let side=CoconutJuggle.side(ball,cycle)
        let release=CoconutJuggle.firstRelease+Double(ball)*CoconutJuggle.cadence+Double(cycle)*CoconutJuggle.period
        let catchTime=release+CoconutJuggle.flight
        let handOut=(CoconutJuggle.handCenter(side:side,at:release)-CoconutJuggle.handCenter(side:side,at:release-epsilon))/Float(epsilon)
        let propOut=(CoconutJuggle.airborne(side:side,phase:Float(epsilon/CoconutJuggle.flight))-CoconutJuggle.launch(side))/Float(epsilon)
        let handIn=(CoconutJuggle.handCenter(side:-side,at:catchTime+epsilon)-CoconutJuggle.handCenter(side:-side,at:catchTime))/Float(epsilon)
        let propIn=(CoconutJuggle.catchPoint(-side)-CoconutJuggle.airborne(side:side,phase:Float(1-epsilon/CoconutJuggle.flight)))/Float(epsilon)
        velocityMismatch=max(velocityMismatch,max(length(handOut-propOut),length(handIn-propIn)))
    }}
    let report:[String:Any]=["maximumAuthoredHandoffVelocityMismatch":velocityMismatch,"minimumAllCenterSeparation":minAllSeparation,"worstHeadTime":worstHeadTime,"minimumSampledHeadClearance":minHeadClearance,"headSamples":head.count,"maximumHandoffJump":maxHandoffJump,"minimumAirborneCenterSeparation":minSeparation,"coconutDiameter":CoconutJuggle.radius*2,"note":"Handoffs are checked against solved wrists, not only authored targets. Does not establish original visual fidelity."]
    try FileManager.default.createDirectory(atPath:"Validation/Juggle",withIntermediateDirectories:true)
    let data=try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]);try data.write(to:URL(fileURLWithPath:"Validation/Juggle/checks.json"));print(String(decoding:data,as:UTF8.self))
    guard velocityMismatch<0.02,minAllSeparation>CoconutJuggle.radius*2*1.12,minHeadClearance>0,maxHandoffJump<0.02,minSeparation>CoconutJuggle.radius*2*1.12 else {throw failure("Juggling contact or separation failed")}
}
