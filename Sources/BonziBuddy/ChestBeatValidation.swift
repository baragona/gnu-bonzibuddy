import Foundation
import simd

func chestBeatContacts(mesh:FanMeshData) throws -> [String:Any] {
    let rig=try FanRig(url:URL(fileURLWithPath:"Resources/FanModel/FanRig.json"))
    struct Sample {let p:SIMD4<Float>;let ids:[Int];let weights:[Float]}
    var hands:[[Sample]]=[[],[]],chest:[Sample]=[]
    for i in stride(from:0,to:mesh.vertices.count/128,by:3) {
        let v=(0..<32).map {c in mesh.vertices.withUnsafeBytes {$0.loadUnaligned(fromByteOffset:i*128+c*4,as:Float.self)}}
        let ids=Array(v[16..<24]).map(Int.init),weights=Array(v[24..<32])
        let sample=Sample(p:[v[0],v[1],v[2],1],ids:ids,weights:weights)
        for (side,range) in [(0,24...38),(1,41...54)] {
            if zip(ids,weights).filter({range.contains($0.0)}).reduce(Float(0),{$0+$1.1})>0.8 {hands[side].append(sample)}
        }
        if v[6]>0.3,zip(ids,weights).filter({[20,21].contains($0.0)}).reduce(Float(0),{$0+$1.1})>0.8 {chest.append(sample)}
    }
    guard hands.allSatisfy({!$0.isEmpty}),!chest.isEmpty else {throw failure("Missing chest/fist surface samples")}
    func posed(_ samples:[Sample],_ bones:[Instance])->[SIMD3<Float>] {
        samples.map {v in
            var p=SIMD4<Float>.zero
            for (id,w) in zip(v.ids,v.weights) where w>0 {p += bones[id].model*v.p*w}
            return SIMD3(p.x,p.y,p.z)
        }
    }
    var contacts:[[String:Any]]=[],footDrift:Float=0
    var first:[Instance]=[]
    for frame in 0...180 {
        let t=Double(frame)/120
        rig.updateLiveAction(.chestBeat,started:0,at:t,elapsed:t)
        let bones=rig.instances(yaw:0,pitch:0,at:t)
        if first.isEmpty {first=bones}
        for joint in [14,15,18,19] {
            for column in 0..<4 {footDrift=max(footDrift,length(bones[joint].model[column]-first[joint].model[column]))}
        }
        if [48,72,96,120,144].contains(frame) {
            let side=[72,120].contains(frame) ? 1:0
            let body=posed(chest,bones),fist=posed(hands[side],bones)
            var closest=Float.infinity
            for a in fist {for b in body {closest=min(closest,length(a-b))}}
            guard closest<0.03 else {throw failure("Chest-beating fist missed the torso at \(t): \(closest)")}
            contacts.append(["time":t,"hand":side==0 ? "left":"right","nearestSurfaceDistance":closest])
        }
    }
    guard footDrift<0.00001,contacts.count==5 else {throw failure("Chest beating foot drift \(footDrift), contacts \(contacts.count)")}
    return ["maximumFootMatrixDrift":footDrift,"chestSamples":chest.count,"handSamples":hands.map(\.count),"beats":contacts,"timelineSamples":181,"note":"Nearest skinned surface samples measure fist/chest proximity; they do not prove absence of penetration."]
}
