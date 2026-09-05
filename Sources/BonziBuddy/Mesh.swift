import Foundation
import simd

// The runtime asset contains indexed triangles, smooth normals, vertex colors,
// and two bone influences. Modeling volumes are used only by the offline baker.
struct SkinVertex {
    var position0: SIMD4<Float>
    var normal0: SIMD4<Float>
    var position1: SIMD4<Float>
    var normal1: SIMD4<Float>
    var color: SIMD4<Float>
    var skin: SIMD4<Float>
}
struct PolygonMesh {
    var vertices: [SkinVertex]
    var indices: [UInt32]
    func save(to url: URL) throws {
        var header: [UInt32] = [0x424F4E5A,3,UInt32(vertices.count),UInt32(indices.count),UInt32(MemoryLayout<SkinVertex>.stride)]
        var data = header.withUnsafeMutableBytes { Data($0) }
        vertices.withUnsafeBytes { data.append(contentsOf:$0) }
        indices.withUnsafeBytes { data.append(contentsOf:$0) }
        try data.write(to:url,options:.atomic)
    }
    static func load(from url:URL) throws -> PolygonMesh {
        let data = try Data(contentsOf:url)
        guard data.count >= 20 else { throw failure("Truncated mesh header") }
        let h: [UInt32] = (0..<5).map { offset in data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset:offset*4,as:UInt32.self) } }
        guard h[0] == 0x424F4E5A, h[1] == 3, h[4] == MemoryLayout<SkinVertex>.stride else { throw failure("Unsupported mesh format") }
        let count = Int(h[2]), indexCount = Int(h[3]), stride = MemoryLayout<SkinVertex>.stride
        guard count > 0, indexCount%3 == 0, data.count == 20+count*stride+indexCount*4 else { throw failure("Invalid mesh size") }
        let vertices: [SkinVertex] = (0..<count).map { i in data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset:20+i*stride,as:SkinVertex.self) } }
        let indices: [UInt32] = (0..<indexCount).map { i in data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset:20+count*stride+i*4,as:UInt32.self) } }
        guard indices.allSatisfy({ $0 < count }) else { throw failure("Invalid mesh index") }
        return PolygonMesh(vertices:vertices,indices:indices)
    }
}

private struct ModelingVolume {
    let bone:Int
    let inverse:simd_float4x4
    let normalMatrix:simd_float3x3
    let radius:Float
    let color:SIMD4<Float>
    let skullProfile:Bool
    let lowerTorso:Bool
    let dorsalFoot:Bool
    let browSide:Float
    let taperedNose:Bool
    let mouthBacking:Bool
    func distance(_ p:SIMD3<Float>) -> Float {
        var q = inverse * SIMD4(p,1)
        if skullProfile {
            let shoulder=(q.y-0.55)/0.22,crown=(q.y-0.87)/0.11
            let width=1+0.065*exp(-shoulder*shoulder)-0.12*exp(-crown*crown)
            q.x /= width
            q.z /= 1+(width-1)*0.5
        }
        if lowerTorso {
            let t=(q.y+0.58)/0.18
            let fullness=1+0.11*exp(-t*t)
            q.x /= fullness
            q.z /= 1+(fullness-1)*0.35
        }
        if dorsalFoot {
            // A narrow heel widens toward the metatarsals; the arch slopes into the toes.
            q.x /= 1+0.30*min(1,max(-1,q.z))
            let front = min(1,max(0,q.z))
            q.y = (q.y+0.25*front)/(1-0.5*front)
        }
        if browSide != 0 {
            // Follow the forehead toward the temples instead of leaving straight tips exposed.
            q.z += (0.045*q.x*q.x+browSide*0.030*q.x)/0.025
        }
        if taperedNose { q.x /= 0.55+0.45*min(1,max(0,(q.y+1)*0.5)) }
        return (length(SIMD3(q.x,q.y,q.z))-1)*radius
    }
}

func bakeMesh() throws {
    let character = Character(); character.bindPose = true
    let bones = character.instances(at:0)
    let volumes = bones.enumerated().map { i,b -> ModelingVolume in
        let m = b.model, inverse = m.inverse
        let radius = min(length(m.columns.0),min(length(m.columns.1),length(m.columns.2)))
        return ModelingVolume(bone:i,inverse:inverse,normalMatrix:simd_float3x3(columns:(SIMD3(m.columns.0.x,m.columns.0.y,m.columns.0.z),SIMD3(m.columns.1.x,m.columns.1.y,m.columns.1.z),SIMD3(m.columns.2.x,m.columns.2.y,m.columns.2.z))).transpose,radius:radius,color:b.color,skullProfile:i==character.headBoneStart,lowerTorso:i==0,dorsalFoot:character.footBones.enumerated().contains { $0.offset % 5 == 0 && $0.element == i },browSide:character.browBones.contains(i) ? (m.columns.3.x > 0 ? 1 : -1) : 0,taperedNose:character.surfaces[i] == .nose,mouthBacking:character.surfaces[i] == .mouth)
    }
    // The organic shell is welded together. Eyes, pupils, and mouth are separate
    // anatomical surfaces, preserving crisp boundaries and independent eyelids.
    let shell = volumes.filter { character.surfaces[$0.bone] == .skin && !character.armBones.contains($0.bone) }
    let details = volumes.filter { character.surfaces[$0.bone] != .skin && character.surfaces[$0.bone] != .lid }.map { [$0] }
    let groups = [shell.filter { $0.bone < character.headBoneStart },shell.filter { $0.bone >= character.headBoneStart }] + details
    let mouth = volumes.first { $0.mouthBacking }!
    var mouthCut = bones[mouth.bone].model
    mouthCut.columns.3.z += 0.075
    mouthCut.columns.3.y -= 0.06
    mouthCut.columns.0 = [0.240,0,0,0]
    mouthCut.columns.1 = [0,0.007,0,0]
    mouthCut.columns.2 = [0,0,0.08,0]
    let mouthCutInverse = mouthCut.inverse
    var output = PolygonMesh(vertices:[],indices:[])
    var worldPositions:[SIMD3<Float>] = []
    let step:Float = 0.014
    let tetrahedra = [[0,5,1,6],[0,1,2,6],[0,2,3,6],[0,3,7,6],[0,7,4,6],[0,4,5,6]]
    for (groupNumber,group) in groups.enumerated() {
        var lower = SIMD3<Float>(repeating:Float.infinity), upper = SIMD3<Float>(repeating:-Float.infinity)
        for v in group {
            let m = bones[v.bone].model
            let center = SIMD3(m.columns.3.x,m.columns.3.y,m.columns.3.z)
            let extent = SIMD3<Float>(length(SIMD3(m.columns.0.x,m.columns.1.x,m.columns.2.x)),length(SIMD3(m.columns.0.y,m.columns.1.y,m.columns.2.y)),length(SIMD3(m.columns.0.z,m.columns.1.z,m.columns.2.z))) + SIMD3<Float>(repeating:0.07)
            lower = simd_min(lower,center-extent); upper = simd_max(upper,center+extent)
        }
        let spacing = groupNumber == 1 ? step*0.36 : group.count == 1 ? step*0.45 : step
        let nx = Int(ceil((upper.x-lower.x)/spacing))+1, ny = Int(ceil((upper.y-lower.y)/spacing))+1, nz = Int(ceil((upper.z-lower.z)/spacing))+1
        func position(_ id:Int) -> SIMD3<Float> { lower+SIMD3(Float(id%nx),Float((id/nx)%ny),Float(id/(nx*ny)))*spacing }
        func field(_ p:SIMD3<Float>) -> Float {
            var d:Float = 100
            for v in group {
                let b = v.distance(p)
                // Facial pads and brow ridges need broad anatomical transitions.
                let k:Float = v.browSide != 0 ? 0.012 : min(groupNumber == 1 ? 0.040 : 0.035,v.radius*(groupNumber == 1 ? 0.4 : 0.35))
                let h = max(k-abs(d-b),0)/k
                d = min(d,b)-h*h*k*0.25
            }
            if groupNumber == 0 {
                let navel = (p-SIMD3<Float>(0,-0.24,0.363))/SIMD3<Float>(0.017,0.020,0.016)
                d = max(d,-(length(navel)-1)*0.014)
            }
            if groupNumber == 1 {
                var q = mouthCutInverse * SIMD4(p,1)
                q.y -= 0.105*q.x*q.x/0.007
                q.z += 0.07*q.x*q.x/0.08
                let cavity = (length(SIMD3(q.x,q.y,q.z))-1)*0.015
                d = max(d,-cavity)
            }
            return d
        }
        var grid = [Float](repeating:0,count:nx*ny*nz)
        for i in grid.indices { grid[i] = field(position(i)) }
        var edgeVertices:[UInt64:UInt32] = [:]
        func vertex(_ a:Int,_ b:Int) -> UInt32 {
            let key = UInt64(min(a,b))<<32 | UInt64(max(a,b))
            if let existing = edgeVertices[key] { return existing }
            let t = grid[a]/(grid[a]-grid[b]), p = mix(position(a),position(b),t:t)
            let e:Float = 0.002
            let normal = normalize(SIMD3(field(p+[e,0,0])-field(p-[e,0,0]),field(p+[0,e,0])-field(p-[0,e,0]),field(p+[0,0,e])-field(p-[0,0,e])))
            let closest = group.sorted { $0.distance(p) < $1.distance(p) }
            let v0 = closest[0], v1 = closest.count > 1 ? closest[1] : closest[0]
            let delta = max(0,v1.distance(p)-v0.distance(p))
            let w:Float = group.count == 1 ? 1 : 1-0.5*max(0,1-delta/0.045)
            let n0 = v0.normalMatrix*normal, n1 = v1.normalMatrix*normal
            // Material blending must remain continuous when the nearest pair changes.
            // Skinning keeps two influences, but material color uses the whole field.
            var color = SIMD4<Float>(repeating:0), materialWeight:Float = 0
            let nearestDistance = v0.distance(p)
            for volume in group {
                let weight = exp(-(volume.distance(p)-nearestDistance)/0.020)
                color += volume.color*weight; materialWeight += weight
            }
            color /= materialWeight
            for (volume,weight) in [(v0,w),(v1,1-w)] where character.palmBones.contains(volume.bone) {
                let local = volume.inverse*SIMD4(p,1)
                let palm = min(1,max(0,(-local.z-0.1)/0.5))*weight
                color = color*(1-palm)+SIMD4<Float>(0.812,0.675,0.944,1)*palm
            }
            if groupNumber == 1 {
                // Recessed oral surfaces use an interior material instead of cheek highlights.
                let interior = min(1,max(0,-min(v0.distance(p),v1.distance(p))/0.014))
                color = color*(1-interior)+SIMD4<Float>(0.49,0.33,0.63,1)*interior
            }
            var jawWeight:Float = 0
            if groupNumber == 1 {
                let q = mouthCutInverse*SIMD4(p,1)
                let belowSmile = q.y-0.105*q.x*q.x/0.007
                func smooth(_ low:Float,_ high:Float,_ value:Float) -> Float { let t = min(1,max(0,(value-low)/(high-low))); return t*t*(3-2*t) }
                jawWeight = (1-smooth(-1,1,belowSmile))*(1-smooth(0.7,1.25,abs(q.x)))*smooth(0.10,0.22,p.z)
                let innerLip = (1-smooth(1,2,abs(belowSmile)))*(1-smooth(0.85,1.15,abs(q.x)))*smooth(0.10,0.22,p.z)
                color = color*(1-innerLip)+SIMD4<Float>(0.53,0.36,0.68,1)*innerLip
            }
            output.vertices.append(SkinVertex(position0:v0.inverse*SIMD4(p,1),normal0:SIMD4(n0,0),position1:v1.inverse*SIMD4(p,1),normal1:SIMD4(n1,0),color:color,skin:[Float(v0.bone),Float(v1.bone),w,jawWeight]))
            worldPositions.append(p)
            let index = UInt32(output.vertices.count-1); edgeVertices[key] = index
            return index
        }
        func triangle(_ a:UInt32,_ b:UInt32,_ c:UInt32) {
            let p = worldPositions[Int(a)], q = worldPositions[Int(b)], r = worldPositions[Int(c)]
            let cross = simd_cross(q-p,r-p)
            guard length_squared(cross) > 0 else { return }
            let middle = (p+q+r)/3, n = normalize(cross)*0.001
            if field(middle+n) > field(middle-n) { output.indices += [a,b,c] } else { output.indices += [a,c,b] }
        }
        for z in 0..<nz-1 { for y in 0..<ny-1 { for x in 0..<nx-1 {
            let i = (z*ny+y)*nx+x
            let corners = [i,i+1,i+1+nx,i+nx,i+nx*ny,i+nx*ny+1,i+nx*ny+nx+1,i+nx*ny+nx]
            let values = corners.map { grid[$0] }
            if values.allSatisfy({ $0>=0 }) || values.allSatisfy({ $0<0 }) { continue }
            for tet in tetrahedra {
                let inside = tet.filter { values[$0]<0 }, outside = tet.filter { values[$0]>=0 }
                if inside.count == 1 {
                    let v = outside.map { vertex(corners[inside[0]],corners[$0]) }; triangle(v[0],v[1],v[2])
                } else if inside.count == 3 {
                    let v = inside.map { vertex(corners[outside[0]],corners[$0]) }; triangle(v[0],v[1],v[2])
                } else if inside.count == 2 {
                    let a = vertex(corners[inside[0]],corners[outside[0]]), b = vertex(corners[inside[0]],corners[outside[1]])
                    let c = vertex(corners[inside[1]],corners[outside[0]]), d = vertex(corners[inside[1]],corners[outside[1]])
                    triangle(a,b,c); triangle(b,d,c)
                }
            }
        } } }
        print("Baked surface \(groupNumber+1)/\(groups.count)")
    }
    // A closed, thin spherical patch folds above each eye when open.
    for bone in bones.indices where character.surfaces[bone] == .lid {
        let base=UInt32(output.vertices.count), columns=25, rows=17, layer=columns*rows
        for back in 0..<2 { for row in 0..<rows { for col in 0..<columns {
            let u=Float(col)/Float(columns-1),v=Float(row)/Float(rows-1)
            let latitude=asin(Float(0.995))+(Float.pi/2-0.001-asin(Float(0.995)))*v
            let phi=(u-0.5)*2*Float.pi
            var local=SIMD3(cos(latitude)*sin(phi),sin(latitude),cos(latitude)*cos(phi))
            if back==1 { local *= 0.98 }
            var p=bones[bone].model*SIMD4(local,1)
            let backward=normalize(SIMD3(bones[bone].model.columns.2.x,bones[bone].model.columns.2.y,bones[bone].model.columns.2.z))*0.120
            p -= SIMD4(backward,0)
            var color=bones[bone].color;color.w=1
            output.vertices.append(SkinVertex(position0:[u,v,Float(back),0],normal0:.zero,position1:.zero,normal1:.zero,color:color,skin:[Float(bone),Float(bone),-2,0]))
            worldPositions.append(SIMD3(p.x,p.y,p.z))
        } } }
        for back in 0..<2 { for row in 0..<rows-1 { for col in 0..<columns-1 {
            let a=base+UInt32(back*layer+row*columns+col),b=a+1,c=a+UInt32(columns),d=c+1
            output.indices += back==0 ? [a,b,c,b,d,c] : [a,c,b,b,c,d]
        } } }
        var boundary=[Int]()
        boundary += Array(0..<columns)
        boundary += (1..<rows).map{$0*columns+columns-1}
        boundary += stride(from:columns-2,through:0,by:-1).map{(rows-1)*columns+$0}
        boundary += stride(from:rows-2,through:1,by:-1).map{$0*columns}
        for i in boundary.indices {
            let a=base+UInt32(boundary[i]),b=base+UInt32(boundary[(i+1)%boundary.count]),c=a+UInt32(layer),d=b+UInt32(layer)
            output.indices += [a,c,b,b,c,d]
        }
    }
    for arm in stride(from:0,to:character.armBones.count,by:2) {
        let upperBone=character.armBones[arm], lowerBone=character.armBones[arm+1]
        let upper=bones[upperBone].model, lower=bones[lowerBone].model
        func endpoint(_ m:simd_float4x4,_ sign:Float) -> SIMD3<Float> {
            let axis=SIMD3(m.columns.1.x,m.columns.1.y,m.columns.1.z)
            let radius=length(SIMD3(m.columns.0.x,m.columns.0.y,m.columns.0.z))
            return SIMD3(m.columns.3.x,m.columns.3.y,m.columns.3.z)+normalize(axis)*(length(axis)-radius*0.35)*sign
        }
        let shoulder=endpoint(upper,-1), elbow=endpoint(upper,1), wrist=endpoint(lower,1)-normalize(SIMD3(bones[lowerBone+1].model.columns.1.x,bones[lowerBone+1].model.columns.1.y,bones[lowerBone+1].model.columns.1.z))*0.035
        func center(_ t:Float) -> SIMD3<Float> {
            let first=t<=0.5, u=first ? t*2 : (t-0.5)*2
            let a=first ? shoulder : elbow, b=first ? elbow : wrist
            let m0=first ? elbow-shoulder : (wrist-shoulder)*0.5
            let m1=first ? (wrist-shoulder)*0.5 : wrist-elbow
            return (2*u*u*u-3*u*u+1)*a+(u*u*u-2*u*u+u)*m0+(-2*u*u*u+3*u*u)*b+(u*u*u-u*u)*m1
        }
        let base=UInt32(output.vertices.count), rings=49, sides=20
        for ring in 0..<rings {
            let t=Float(ring)/Float(rings-1)
            let tangent=normalize(center(min(1,t+0.001))-center(max(0,t-0.001)))
            let bendNormal=cross(elbow-shoulder,wrist-elbow)
            let frameAxis=length_squared(bendNormal)>0.000001 ? normalize(bendNormal) : SIMD3<Float>(0,0,1)
            let x=normalize(cross(tangent,frameAxis)), z=normalize(cross(x,tangent))
            let radius:Float=0.105-0.060*t
            for side in 0..<sides {
                let angle=Float(side)*2*Float.pi/Float(sides), c=cos(angle), s=sin(angle)
                // skin.z=-1 selects spline deformation, shared by color and shadow passes.
                output.vertices.append(SkinVertex(position0:[t,c,s,radius],normal0:.zero,position1:.zero,normal1:.zero,color:bones[upperBone].color,skin:[Float(upperBone),Float(lowerBone),-1,0]))
                worldPositions.append(center(t)+(x*c+z*s)*radius)
            }
        }
        for ring in 0..<rings-1 { for side in 0..<sides {
            let a=base+UInt32(ring*sides+side),b=base+UInt32(ring*sides+(side+1)%sides),c=a+UInt32(sides),d=b+UInt32(sides)
            output.indices += [a,c,b,b,c,d]
        } }
        // Closed end caps are buried in the shoulder and palm.
        for (ring,t) in [(0,Float(0)),(rings-1,Float(1))] {
            let cap=UInt32(output.vertices.count)
            output.vertices.append(SkinVertex(position0:[t,0,0,0],normal0:.zero,position1:.zero,normal1:.zero,color:bones[upperBone].color,skin:[Float(upperBone),Float(lowerBone),-1,0]))
            worldPositions.append(center(t))
            for side in 0..<sides {
                let a=base+UInt32(ring*sides+side),b=base+UInt32(ring*sides+(side+1)%sides)
                output.indices += ring==0 ? [cap,a,b] : [cap,b,a]
            }
        }
    }
    try FileManager.default.createDirectory(atPath:"Resources",withIntermediateDirectories:true)
    try output.save(to:URL(fileURLWithPath:"Resources/Bonzi.mesh"))
    var obj = "# BonziBuddy continuous polygon mesh, neutral bind pose\n"
    for p in worldPositions { obj += "v \(p.x) \(p.y) \(p.z)\n" }
    for i in stride(from:0,to:output.indices.count,by:3) { obj += "f \(output.indices[i]+1) \(output.indices[i+1]+1) \(output.indices[i+2]+1)\n" }
    try obj.write(toFile:"Resources/Bonzi.obj",atomically:true,encoding:.utf8)
    let report:[String:Any] = ["vertices":output.vertices.count,"triangles":output.indices.count/3,"bones":bones.count,"anatomicalSurfaces":groups.count,"gridSpacing":step,"format":"Indexed triangle mesh with smooth normals, vertex colors, two bone influences and spline-deformed arm rings; OBJ exports neutral geometry."]
    try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:"Validation/mesh.json"))
}
