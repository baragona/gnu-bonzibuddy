import simd

// Indexed hollow shells, rims, curved headband, and telescoping antenna.
// Coordinates are relative to the head attachment, as with the imported glasses.
enum HeadphonesGeometry {
    static func mesh()->([PropVertex],[UInt32]) {
        var vertices:[PropVertex]=[],indices:[UInt32]=[]
        func patch(rows:Int,columns:Int,material:Float,flip:Bool=false,surface:(Float,Float)->SIMD3<Float>) {
            let start=UInt32(vertices.count)
            for row in 0...rows {for col in 0...columns {
                let u=Float(col)/Float(columns),v=Float(row)/Float(rows),p=surface(u,v)
                let du=surface(u+0.0001,v)-surface(u-0.0001,v)
                let dv=surface(u,v+0.0001)-surface(u,v-0.0001)
                var n=cross(du,dv);n=length(n)>1e-18 ? normalize(n):SIMD3<Float>(1,0,0)
                if flip {n = -n}
                vertices.append(PropVertex(position:SIMD4(p,1),normal:SIMD4(n,0),uv:[u,v,0,material]))
                if row<rows && col<columns {
                    let a=start+UInt32(row*(columns+1)+col),b=a+UInt32(columns+1)
                    indices += flip ? [a,b,a+1,a+1,b,b+1]:[a,a+1,b,a+1,b+1,b]
                }
            }}
        }
        for side:Float in [-1,1] {
            // The two surfaces share their opening plane; an annulus closes the wall.
            for inner in [false,true] {
                patch(rows:24,columns:64,material:inner ? 2:0,flip:(side>0) != inner) {u,v in
                    let angle=u*2*Float.pi,phi=(0.001+v*0.999)*Float.pi/2
                    let radius:Float=inner ? 0.136:0.160,depth:Float=inner ? 0.151:0.178
                    let rough:Float=inner ? 1:1+0.015*sin(angle*9+phi*5)*sin(phi)
                    return [side*(0.330+depth*cos(phi)),0.245+radius*sin(phi)*cos(angle)*rough,0.085+radius*sin(phi)*sin(angle)*rough]
                }
            }
            patch(rows:1,columns:64,material:2,flip:side<0) {u,v in
                let angle=u*2*Float.pi
                let outer:Float=0.160*(1+0.015*sin(angle*9+Float.pi*2.5))
                let radius:Float=0.136+(outer-0.136)*v
                return [side*0.330,0.245+radius*cos(angle),0.085+radius*sin(angle)]
            }
        }
        func tube(points:Int,radius:Float,material:Float,curve:(Float)->SIMD3<Float>) {
            patch(rows:points,columns:12,material:material) {u,v in
                let p=curve(v),axis=normalize(curve(v+0.0001)-curve(v-0.0001))
                let reference:SIMD3<Float>=abs(axis.z)<0.9 ? [0,0,1]:[0,1,0]
                let x=normalize(cross(axis,reference)),y=cross(axis,x),a=u*2*Float.pi
                return p+radius*(cos(a)*x+sin(a)*y)
            }
        }
        tube(points:64,radius:0.013,material:1) {v in
            let a=v*Float.pi
            return [0.370*cos(a),0.245+0.505*sin(a),0.055]
        }
        tube(points:4,radius:0.011,material:1) {v in [-0.320,0.335+0.075*v,0.085]}
        tube(points:8,radius:0.006,material:3) {v in [-0.320+0.030*v,0.395+0.58*v,0.085]}
        tube(points:4,radius:0.008,material:1) {v in [-0.290,0.965+0.025*v,0.085]}
        return (vertices,indices)
    }
}
