import simd

// Thick, curved wing outlines: each wing is a separate rigid articulation around
// the thorax. Both faces and the edge are actual indexed geometry for shadows.
enum ButterflyGeometry {
    static func mesh(_ kind:PropKind)->([PropVertex],[UInt32]) {
        var vertices:[PropVertex]=[],indices:[UInt32]=[]
        if kind == .butterflyBody {
            let rows=20,columns=24
            for row in 0...rows {for column in 0...columns {
                let v=Float(row)/Float(rows),u=Float(column)/Float(columns)
                let theta=v*Float.pi,phi=u*2*Float.pi
                let n=SIMD3<Float>(sin(theta)*cos(phi),cos(theta),sin(theta)*sin(phi))
                let p=n*SIMD3<Float>(0.016,0.050,0.016)
                vertices.append(PropVertex(position:SIMD4(p,1),normal:SIMD4(normalize(n/SIMD3<Float>(0.016,0.050,0.016)),0),uv:[u,v,0,0]))
                if row<rows && column<columns {
                    let a=UInt32(row*(columns+1)+column),b=a+UInt32(columns+1)
                    if row>0 {indices += [a,a+1,b]}
                    if row<rows-1 {indices += [a+1,b+1,b]}
                }
            }}
        } else {
            let outline:[SIMD2<Float>]=[[0.012,-0.035],[0.060,-0.105],[0.140,-0.100],[0.180,-0.035],[0.145,0.015],[0.265,0.120],[0.245,0.205],[0.150,0.200],[0.060,0.120],[0.012,0.050]]
            var edge:[SIMD2<Float>]=[]
            for i in outline.indices {for step in 0..<8 {
                let n=outline.count,p0=outline[(i+n-1)%n],p1=outline[i],p2=outline[(i+1)%n],p3=outline[(i+2)%n],t=Float(step)/8
                let t2=t*t,t3=t2*t
                let f0:Float = -0.5*t3+t2-0.5*t
                let f1:Float = 1.5*t3-2.5*t2+1
                let f2:Float = -1.5*t3+2*t2+0.5*t
                let f3:Float = 0.5*t3-0.5*t2
                var point=p0*f0
                point += p1*f1;point += p2*f2;point += p3*f3
                point.y *= 0.55
                edge.append(point)
            }}
            let root=SIMD2<Float>(0.025,0.025)
            for side:Float in [-1,1] {
                let start=UInt32(vertices.count)
                vertices.append(PropVertex(position:SIMD4(root.x,root.y,side*0.003,1),normal:[0,0,side,0],uv:[root.x/0.27,(root.y+0.11)/0.32,0,1]))
                for p in edge {vertices.append(PropVertex(position:[p.x,p.y,side*0.003,1],normal:[0,0,side,0],uv:[p.x/0.27,(p.y+0.11)/0.32,1,1]))}
                for i in edge.indices {
                    let a=start+1+UInt32(i),b=start+1+UInt32((i+1)%edge.count)
                    indices += side>0 ? [start,a,b]:[start,b,a]
                }
            }
            for i in edge.indices {
                let p=edge[i],q=edge[(i+1)%edge.count],d=q-p,n=normalize(SIMD3<Float>(d.y,-d.x,0)),start=UInt32(vertices.count)
                for (v,z) in [(p,Float(-0.003)),(q,Float(-0.003)),(q,Float(0.003)),(p,Float(0.003))] {
                    vertices.append(PropVertex(position:[v.x,v.y,z,1],normal:SIMD4(n,0),uv:[v.x/0.27,(v.y+0.11)/0.32,1,1]))
                }
                indices += [start,start+1,start+2,start,start+2,start+3]
            }
        }
        if kind == .butterflyBody {
            func filament(_ points:[SIMD3<Float>],radius:Float) {
                for i in 0..<(points.count-1) {
                    let a=points[i],b=points[i+1],axis=normalize(b-a)
                    let x=normalize(cross(axis,SIMD3<Float>(0,0,1))),y=cross(axis,x),start=UInt32(vertices.count)
                    for end in [a,b] {for side in 0...8 {
                        let angle=Float(side)*2*Float.pi/8,n=cos(angle)*x+sin(angle)*y
                        vertices.append(PropVertex(position:SIMD4(end+n*radius,1),normal:SIMD4(n,0),uv:[0,0,0,0]))
                    }}
                    for side in 0..<8 {let a=start+UInt32(side),b=a+9;indices += [a,a+1,b,a+1,b+1,b]}
                }
            }
            for side:Float in [-1,1] {
                filament([[side*0.008,0.050,0],[side*0.022,0.075,0],[side*0.048,0.085,0]],radius:0.003)
                for row in 0..<3 {
                    let y:Float=0.020-Float(row)*0.015,z:Float=Float(row-1)*0.022
                    filament([[side*0.010,y,0],[side*0.048,y-0.025,z],[side*0.030,-0.068,z]],radius:0.0025)
                }
            }
        }
        return (vertices,indices)
    }
}
