import Foundation

// Portable indexed prop buffers, generated offline without a runtime model importer.
struct PropAssetData {
    let vertices:Data
    let indices:Data
    let indexCount:Int
    init(url:URL) throws {
        let data=try Data(contentsOf:url)
        guard data.count>=20 else {throw failure("Truncated prop asset")}
        let h=(0..<5).map {i in data.withUnsafeBytes {$0.loadUnaligned(fromByteOffset:i*4,as:UInt32.self)}}
        let nv=Int(h[2]),ni=Int(h[3])
        guard h[0]==0x42505250,h[1]==1,h[4]==80,nv>0,ni>0,ni%3==0,data.count==20+nv*80+ni*4 else {throw failure("Invalid prop asset layout")}
        vertices=data.subdata(in:20..<(20+nv*80));indices=data.subdata(in:(20+nv*80)..<data.count);indexCount=ni
        for i in 0..<ni {
            guard indices.withUnsafeBytes({$0.loadUnaligned(fromByteOffset:i*4,as:UInt32.self)})<nv else {throw failure("Invalid prop asset index")}
        }
    }
    static func url(_ name:String)->URL {
        let bundled=Bundle.main.resourceURL?.appendingPathComponent("Props/\(name)")
        return bundled.flatMap {FileManager.default.fileExists(atPath:$0.path) ? $0:nil} ?? URL(fileURLWithPath:"Resources/Props/\(name)")
    }
}
