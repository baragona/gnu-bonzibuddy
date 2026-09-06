import simd

// Thin, gently bowed paper with a separate flap hinged at the left edge.
enum LetterGeometry {
    static func mesh(_ kind:PropKind)->([PropVertex],[UInt32]) {
        var vertices:[PropVertex]=[],indices:[UInt32]=[]
        let columns=20,width:Float=0.56,x0:Float=kind == .letterBack ? -0.28:0
        func p(_ u:Float,_ v:Float,_ side:Float)->SIMD3<Float> {
            [x0+width*u,(v-0.5)*0.64,0.018*sin(Float.pi*u)+side*0.001]
        }
        for side:Float in [-1,1] {
            let base=UInt32(vertices.count)
            for row in 0...1 {for column in 0...columns {
                let u=Float(column)/Float(columns),v=Float(row),slope=0.018*Float.pi/width*cos(Float.pi*u)
                vertices.append(PropVertex(position:SIMD4(p(u,v,side),1),normal:SIMD4(normalize(SIMD3<Float>(-slope,0,1))*side,0),uv:[u,v,side,0]))
                if row==0 && column<columns {
                    let a=base+UInt32(column),b=a+UInt32(columns+1)
                    indices += side>0 ? [a,a+1,b,a+1,b+1,b]:[a,b,a+1,a+1,b,b+1]
                }
            }}
        }
        func edge(_ points:[SIMD3<Float>]) {
            let n=normalize(cross(points[1]-points[0],points[2]-points[0])),a=UInt32(vertices.count)
            for point in points {vertices.append(PropVertex(position:SIMD4(point,1),normal:SIMD4(n,0),uv:.zero))}
            indices += [a,a+1,a+2,a,a+2,a+3]
        }
        for i in 0..<columns {
            let a=Float(i)/Float(columns),b=Float(i+1)/Float(columns)
            edge([p(a,0,-1),p(b,0,-1),p(b,0,1),p(a,0,1)])
            edge([p(a,1,1),p(b,1,1),p(b,1,-1),p(a,1,-1)])
        }
        edge([p(0,0,-1),p(0,0,1),p(0,1,1),p(0,1,-1)])
        edge([p(1,0,1),p(1,0,-1),p(1,1,-1),p(1,1,1)])
        return (vertices,indices)
    }
}
