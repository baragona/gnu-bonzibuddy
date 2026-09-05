import simd

// Pad and pencil have real thickness, including the paper stack and graphite tip.
enum WritingGeometry {
    static let paperZ:Float=0.025
    static func mesh(_ kind:PropKind)->([PropVertex],[UInt32]) {
        var vertices:[PropVertex]=[],indices:[UInt32]=[]
        func quad(_ p:[SIMD3<Float>],_ material:Float) {
            let n=normalize(cross(p[1]-p[0],p[2]-p[0])),a=UInt32(vertices.count)
            for (i,v) in p.enumerated() {vertices.append(PropVertex(position:SIMD4(v,1),normal:SIMD4(n,0),uv:[i==1 || i==2 ? 1:0,i>=2 ? 1:0,n.z,material]))}
            indices += [a,a+1,a+2,a,a+2,a+3]
        }
        func box(_ lo:SIMD3<Float>,_ hi:SIMD3<Float>,_ material:Float) {
            let a=lo,b=hi
            quad([[a.x,a.y,b.z],[b.x,a.y,b.z],[b.x,b.y,b.z],[a.x,b.y,b.z]],material)
            quad([[b.x,a.y,a.z],[a.x,a.y,a.z],[a.x,b.y,a.z],[b.x,b.y,a.z]],material)
            quad([[a.x,a.y,a.z],[a.x,a.y,b.z],[a.x,b.y,b.z],[a.x,b.y,a.z]],material)
            quad([[b.x,a.y,b.z],[b.x,a.y,a.z],[b.x,b.y,a.z],[b.x,b.y,b.z]],material)
            quad([[a.x,b.y,b.z],[b.x,b.y,b.z],[b.x,b.y,a.z],[a.x,b.y,a.z]],material)
            quad([[a.x,a.y,a.z],[b.x,a.y,a.z],[b.x,a.y,b.z],[a.x,a.y,b.z]],material)
        }
        func shaft(_ y0:Float,_ y1:Float,_ r0:Float,_ r1:Float,_ material:Float) {
            let count=12
            for i in 0..<count {
                let a=Float(i)*2*Float.pi/Float(count),b=Float(i+1)*2*Float.pi/Float(count)
                quad([[r0*cos(a),y0,r0*sin(a)],[r1*cos(a),y1,r1*sin(a)],[r1*cos(b),y1,r1*sin(b)],[r0*cos(b),y0,r0*sin(b)]],material)
            }
        }
        if kind == .writingPad {
            box([-0.30,-0.22,-0.018],[0.30,0.22,-0.005],0)
            box([-0.285,-0.205,-0.005],[0.285,0.205,paperZ],1)
            box([0.255,-0.23,-0.022],[0.31,0.23,0.035],2)
            for y:Float in [-0.17,-0.08,0.01,0.10,0.19] {
                box([0.25,y-0.008,0.035],[0.317,y+0.008,0.044],3)
            }
        } else {
            // Local origin is the graphite contact point; +Y runs toward the eraser.
            shaft(0,0.025,0.0008,0.006,4)
            shaft(0.025,0.075,0.006,0.022,5)
            shaft(0.075,0.43,0.022,0.022,2)
            shaft(0.43,0.47,0.023,0.023,3)
            shaft(0.47,0.50,0.022,0.021,6)
            quad([[-0.014,0.50,-0.014],[-0.014,0.50,0.014],[0.014,0.50,0.014],[0.014,0.50,-0.014]],6)
        }
        return (vertices,indices)
    }
}
