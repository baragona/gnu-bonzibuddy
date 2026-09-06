import Metal
import simd

// Geometry is built once, then reused by the color and shadow passes. New prop
// types provide their own indexed surface here without changing choreography.
struct PropMesh {
    let vertices:MTLBuffer
    let indices:MTLBuffer
    let indexCount:Int
    init(device:MTLDevice,kind:PropKind) throws {
        var vertices:[PropVertex]=[],indices:[UInt32]=[]
        switch kind {
        case .vine:
            (vertices,indices)=VineGeometry.mesh()
        case .letterBack,.letterFlap:
            (vertices,indices)=LetterGeometry.mesh(kind)
        case .mailbox,.mailboxDoor:
            (vertices,indices)=MailboxGeometry.mesh(kind)
        case .writingPad,.pencil:
            (vertices,indices)=WritingGeometry.mesh(kind)
        case .bookLeft,.bookRight,.bookLeaf:
            (vertices,indices)=BookGeometry.mesh(kind)
        case .butterflyWing,.butterflyBody:
            (vertices,indices)=ButterflyGeometry.mesh(kind)
        case .headphones:
            (vertices,indices)=HeadphonesGeometry.mesh()
        case .sunglasses:
            let asset=try PropAssetData(url:PropAssetData.url("FanSunglasses.mesh"))
            self.vertices=asset.vertices.withUnsafeBytes {device.makeBuffer(bytes:$0.baseAddress!,length:$0.count)!}
            self.indices=asset.indices.withUnsafeBytes {device.makeBuffer(bytes:$0.baseAddress!,length:$0.count)!}
            indexCount=asset.indexCount
            return
        case .bananaFruit,.bananaPeel:
            (vertices,indices)=BananaGeometry.mesh(kind)
        case .globe,.coconut,.dustCloud:
        let rings=kind == .dustCloud ? 12:48,sides=kind == .dustCloud ? 16:96
        func surface(_ u:Float,_ v:Float)->SIMD3<Float> {
            let latitude=Float.pi*(0.5-v),longitude=(u-0.5)*2*Float.pi
            let normal=SIMD3<Float>(sin(longitude)*cos(latitude),sin(latitude),cos(longitude)*cos(latitude))
            if kind == .globe {return normal}
            if kind == .dustCloud {return normal*(1+0.12*sin(longitude*5)*cos(latitude*3))}
            let irregularity=1+0.008*sin(longitude*7+normal.y*5)*cos(latitude)*cos(latitude)+0.004*sin(longitude*13)*cos(latitude)
            return normal*SIMD3<Float>(0.96,1.08,0.92)*irregularity
        }
        for row in 0...rings {
            let v=Float(row)/Float(rings)
            for column in 0...sides {
                let u=Float(column)/Float(sides),p=surface(u,v)
                let tangent=surface(u+0.0001,v)-surface(u-0.0001,v)
                let vertical=surface(u,min(1,v+0.0001))-surface(u,max(0,v-0.0001))
                var normal=cross(tangent,vertical)
                normal=length(normal)>0.00000001 ? normalize(normal):normalize(p)
                if dot(normal,p)<0 {normal = -normal}
                vertices.append(PropVertex(position:SIMD4(p,1),normal:SIMD4(normal,0),uv:[u,v,0,0]))
                if row<rings && column<sides {
                    let a=UInt32(row*(sides+1)+column),b=a+UInt32(sides+1)
                    if row>0 {indices += [a,b,a+1]}
                    if row<rings-1 {indices += [a+1,b,b+1]}
                }
            }
        }
        }
        self.vertices=device.makeBuffer(bytes:vertices,length:vertices.count*MemoryLayout<PropVertex>.stride)!
        self.indices=device.makeBuffer(bytes:indices,length:indices.count*4)!
        indexCount=indices.count
    }
}
