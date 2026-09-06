import Foundation
import simd

// Intersect skinned character triangles with the actual piecewise-linear sheet.
// Facial morph deltas are excluded; this targets chest, arm, and hand penetration.
func bookCharacterIntersections(rig:FanRig,mesh:FanMeshData)->Int {
    struct Skin {var p:SIMD4<Float>;var joints:[Int];var weights:[Float]}
    let skin=(0..<(mesh.vertices.count/128)).map {i -> Skin in
        let v=(0..<32).map {j in mesh.vertices.withUnsafeBytes {$0.loadUnaligned(fromByteOffset:i*128+j*4,as:Float.self)}}
        return Skin(p:[v[0],v[1],v[2],1],joints:(0..<8).map {Int(v[16+$0])},weights:Array(v[24..<32]))
    }
    let indices=(0..<mesh.indexCount).map {i in mesh.indices.withUnsafeBytes {Int($0.loadUnaligned(fromByteOffset:i*4,as:UInt32.self))}}
    let leaf=BookGeometry.mesh(.bookLeaf).0
    let motion=PropMotion()
    var intersections=0
    var byJoint:[Int:Int]=[:]
    for frame in 0...96 {
        let t=6.1+Double(frame)/120
        rig.updateLiveAction(.read,started:0,at:t,elapsed:t)
        let bones=rig.instances(yaw:0,pitch:0,at:t)
        let draws=motion.sample(action:.read,started:0,at:t,cues:rig.routine.props,rig:rig,bones:bones)
        guard let page=draws.first(where:{$0.kind == .bookLeaf}),case let .page(curl)=page.deformation else {continue}
        let inverse=page.model.inverse
        let points=skin.map {s -> SIMD3<Float> in
            var p=SIMD4<Float>.zero
            for j in 0..<8 where s.weights[j]>0 {p += bones[s.joints[j]].model*s.p*s.weights[j]}
            let q=inverse*p
            return SIMD3(q.x,q.y,q.z)
        }
        for triangle in stride(from:0,to:indices.count,by:3) {
            let p=[points[indices[triangle]],points[indices[triangle+1]],points[indices[triangle+2]]]
            let lo=simd_min(p[0],simd_min(p[1],p[2])),hi=simd_max(p[0],simd_max(p[1],p[2]))
            if hi.x<0 || lo.x>BookGeometry.width || hi.y < -0.1625 || lo.y>0.1625 || hi.z < -0.002 || lo.z>0.08 {continue}
            for column in 0..<28 {
                let a=leaf[column].position+(leaf[column].openedPosition-leaf[column].position)*curl
                let b=leaf[column+1].position+(leaf[column+1].openedPosition-leaf[column+1].position)*curl
                if hi.x<a.x || lo.x>b.x {continue}
                let slope=(b.z-a.z)/(b.x-a.x)
                let d=p.map {$0.z-(a.z+slope*($0.x-a.x))}
                var cuts:[SIMD3<Float>]=[]
                for edge in 0..<3 {
                    let next=(edge+1)%3
                    if (d[edge]<0) != (d[next]<0) {cuts.append(p[edge]+(p[next]-p[edge])*(d[edge]/(d[edge]-d[next])))}
                }
                guard cuts.count==2 else {continue}
                // Clip the intersection segment to this sheet strip's rectangle.
                var lower:Float=0,upper:Float=1
                for (axis,minValue,maxValue) in [(0,a.x,b.x),(1,Float(-0.1625),Float(0.1625))] {
                    let origin=cuts[0][axis],delta=cuts[1][axis]-origin
                    if abs(delta)<1e-8 {if origin<minValue || origin>maxValue {upper = -1}}
                    else {
                        let s=(minValue-origin)/delta,e=(maxValue-origin)/delta
                        lower=max(lower,min(s,e));upper=min(upper,max(s,e))
                    }
                }
                if upper>lower+1e-5 {
                    intersections+=1
                    let s=skin[indices[triangle]],j=s.weights.indices.max(by:{s.weights[$0]<s.weights[$1]})!
                    byJoint[s.joints[j],default:0]+=1
                    break
                }
            }
        }
    }
    if intersections>0 {print("Page collision joints: \(byJoint)")}
    return intersections
}
