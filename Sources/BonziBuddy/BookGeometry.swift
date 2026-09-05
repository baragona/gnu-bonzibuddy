import simd

enum BookGeometry {
    static let width:Float=0.46
    static func mesh(_ kind:PropKind)->([PropVertex],[UInt32]) {
        var vertices:[PropVertex]=[],indices:[UInt32]=[]
        if kind == .bookLeaf {
            let columns=28
            for side:Float in [-1,1] {
                let start=UInt32(vertices.count)
                for row in 0...1 {for column in 0...columns {
                    let u=Float(column)/Float(columns),v=Float(row),x=width*u,y=(v-0.5)*0.325,z:Float = -0.07+side*0.001
                    let bend:Float=0.13*sin(Float.pi*u)*u
                    let slope:Float=0.13/width*(sin(Float.pi*u)+Float.pi*u*cos(Float.pi*u))
                    vertices.append(PropVertex(position:[x,y,z,1],normal:[0,0,side,0],uv:[u,v,0,1],openedPosition:[x,y,z+bend,1],openedNormal:SIMD4(normalize(SIMD3<Float>(-slope,0,1))*side,0)))
                    if row==0 && column<columns {
                        let a=start+UInt32(column),b=a+UInt32(columns+1)
                        indices += side>0 ? [a,a+1,b,a+1,b+1,b]:[a,b,a+1,a+1,b,b+1]
                    }
                }}
            }
        } else {
            let side:Float=kind == .bookLeft ? -1:1
            func box(_ lo:SIMD3<Float>,_ hi:SIMD3<Float>,material:Float) {
                let x0=lo.x,x1=hi.x,y0=lo.y,y1=hi.y,z0=lo.z,z1=hi.z
                let faces:[([SIMD3<Float>],SIMD3<Float>,Float)]=[
                    ([[x0,y0,z1],[x1,y0,z1],[x1,y1,z1],[x0,y1,z1]],[0,0,1],1),
                    ([[x1,y0,z0],[x0,y0,z0],[x0,y1,z0],[x1,y1,z0]],[0,0,-1],-1),
                    ([[x1,y0,z1],[x1,y0,z0],[x1,y1,z0],[x1,y1,z1]],[1,0,0],0),
                    ([[x0,y0,z0],[x0,y0,z1],[x0,y1,z1],[x0,y1,z0]],[-1,0,0],0),
                    ([[x0,y1,z1],[x1,y1,z1],[x1,y1,z0],[x0,y1,z0]],[0,1,0],0),
                    ([[x0,y0,z0],[x1,y0,z0],[x1,y0,z1],[x0,y0,z1]],[0,-1,0],0)
                ]
                for (points,normal,face) in faces {
                    let start=UInt32(vertices.count)
                    for (i,p) in points.enumerated() {
                        vertices.append(PropVertex(position:SIMD4(p,1),normal:SIMD4(normal,0),uv:[i==1 || i==2 ? 1:0,i>=2 ? 1:0,face,material]))
                    }
                    indices += [start,start+1,start+2,start,start+2,start+3]
                }
            }
            let x0=min(0,side*width),x1=max(0,side*width)
            box([x0,-0.18,-0.025],[x1,0.18,0.015],material:0)
            box([x0+0.014,-0.164,-0.064],[x1-0.014,0.164,-0.025],material:1)
        }
        return (vertices,indices)
    }
}
