import Foundation
import simd

func validateFanContacts() throws {
    let rig=try FanRig(url:URL(fileURLWithPath:"Resources/FanModel/FanRig.json"))
    let mesh=try FanMeshData(url:URL(fileURLWithPath:"Resources/FanModel/FanRigged.mesh"))
    struct Sample { let p:SIMD4<Float>;let ids:[Int];let weights:[Float] }
    var palms:[[Sample]]=[[],[]]
    for i in 0..<(mesh.vertices.count/128) {
        let v=(0..<32).map { c in mesh.vertices.withUnsafeBytes { $0.loadUnaligned(fromByteOffset:i*128+c*4,as:Float.self) } }
        let ids=Array(v[16..<24]).map(Int.init),weights=Array(v[24..<32])
        for (hand,joint) in [26,42].enumerated() {
            let weight=zip(ids,weights).filter { $0.0==joint }.reduce(Float(0)) { $0+$1.1 }
            if weight>0.6 && v[5]<(-0.4) { palms[hand].append(Sample(p:SIMD4(v[0],v[1],v[2],1),ids:ids,weights:weights)) }
        }
    }
    guard palms.allSatisfy({ !$0.isEmpty }) else { throw failure("Missing weighted palm samples") }
    var records:[[String:Any]]=[]
    for frame in 3...5 {
        rig.action = .clap;rig.actionTime=Double(frame)/15
        let bones=rig.instances(yaw:0,pitch:0,at:rig.actionTime)
        let points=palms.map { samples in samples.map { v -> SIMD3<Float> in
            var p=SIMD4<Float>.zero
            for (id,w) in zip(v.ids,v.weights) { p+=(bones[id].model*v.p)*w }
            return SIMD3(p.x,p.y,p.z)
        } }
        var closest=Float.infinity
        for a in points[0] { for b in points[1] { closest=min(closest,length(a-b)) } }
        let centers=points.map { $0.reduce(SIMD3<Float>.zero,+)/Float($0.count) }
        records.append(["frame":frame,"closestPalmSurfaceDistance":closest,"palmCenterDistance":length(centers[0]-centers[1]),"centers":centers.map { [$0.x,$0.y,$0.z] }])
    }
    guard (records[0]["closestPalmSurfaceDistance"] as! Float)>0.04,records.dropFirst().allSatisfy({ ($0["closestPalmSurfaceDistance"] as! Float)<0.01 }) else { throw failure("Clap did not separate and make palm contact") }
    let report:[String:Any]=["palmSamples":palms.map(\.count),"clap":records,"note":"Distances between weighted palm-surface samples at open and contact beats; does not prove absence of penetration."]
    try FileManager.default.createDirectory(atPath:"Validation/FanActions",withIntermediateDirectories:true)
    let data=try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]);try data.write(to:URL(fileURLWithPath:"Validation/FanActions/contacts.json"));print(String(decoding:data,as:UTF8.self))
}
