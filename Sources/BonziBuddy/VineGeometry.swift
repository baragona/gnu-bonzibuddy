import simd

// uv.z stores each vertex's stem attachment distance. Leaves use one rigid
// attachment frame while the indexed stem bends continuously on the GPU.
enum VineGeometry {
    static let length:Float=2.4
    static func mesh()->([PropVertex],[UInt32]) {
        var vertices:[PropVertex]=[],indices:[UInt32]=[]
        func triangle(_ a:UInt32,_ b:UInt32,_ c:UInt32) {
            func xyz(_ p:SIMD4<Float>)->SIMD3<Float> {SIMD3(p.x,p.y,p.z)}
            let p=xyz(vertices[Int(a)].position),q=xyz(vertices[Int(b)].position),r=xyz(vertices[Int(c)].position)
            let normal=xyz(vertices[Int(a)].normal+vertices[Int(b)].normal+vertices[Int(c)].normal)
            indices += dot(cross(q-p,r-p),normal)>=0 ? [a,b,c]:[a,c,b]
        }
        let rows=64,sides=12
        for row in 0...rows {for column in 0...sides {
            let t=Float(row)/Float(rows),u=Float(column)/Float(sides),a=u*2*Float.pi
            let radius:Float=0.014-0.005*t,n=SIMD3<Float>(cos(a),0.005/length,sin(a))
            vertices.append(PropVertex(position:[radius*cos(a),t*length,radius*sin(a),1],normal:SIMD4(normalize(n),0),uv:[u,t,t,0]))
            if row<rows && column<sides {
                let a=UInt32(row*(sides+1)+column),b=a+UInt32(sides+1)
                indices += [a,b,a+1,a+1,b,b+1]
            }
        }}
        for t:Float in [0,1] {
            let start=UInt32(vertices.count),radius:Float=0.014-0.005*t,normal=SIMD4<Float>(0,t==0 ? -1:1,0,0)
            vertices.append(PropVertex(position:[0,t*length,0,1],normal:normal,uv:[0,t,t,0]))
            for i in 0...sides {let a=Float(i)*2*Float.pi/Float(sides)
                vertices.append(PropVertex(position:[radius*cos(a),t*length,radius*sin(a),1],normal:normal,uv:[Float(i)/Float(sides),t,t,0]))
            }
            for i in 0..<sides {triangle(start,start+1+UInt32(i),start+2+UInt32(i))}
        }
        for (attachment,turn) in [(Float(0.28),Float(0)),(0.54,Float.pi),(0.78,Float(0.35))] {
            let start=UInt32(vertices.count),rows=16,columns=12,rotation=simd_quatf(angle:turn,axis:[0,1,0])
            func surface(_ t:Float,_ u:Float)->SIMD3<Float> {
                let a=u*2*Float.pi,w=sin(Float.pi*t)
                return rotation.act([0.011+0.18*t,0.04*t+0.048*w*cos(a),0.013*w+0.004*w*sin(a)])+[0,attachment*length,0]
            }
            for row in 0...rows {for column in 0...columns {
                let t=Float(row)/Float(rows),u=Float(column)/Float(columns),p=surface(t,u)
                let dt=surface(min(1,t+0.0001),u)-surface(max(0,t-0.0001),u)
                let du=surface(t,u+0.0001)-surface(t,u-0.0001)
                let n=normalize(row==0 ? rotation.act(SIMD3<Float>(-1,0,0)):row==rows ? rotation.act(SIMD3<Float>(1,0,0)):cross(du,dt))
                vertices.append(PropVertex(position:SIMD4(p,1),normal:SIMD4(n,0),uv:[t,u,attachment,1]))
            }}
            for row in 0..<rows {for column in 0..<columns {
                let a=start+UInt32(row*(columns+1)+column),b=a+UInt32(columns+1)
                if row>0 {triangle(a,b,a+1)}
                if row<rows-1 {triangle(a+1,b,b+1)}
            }}
        }
        return (vertices,indices)
    }
}
