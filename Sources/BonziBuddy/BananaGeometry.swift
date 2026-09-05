import simd

// A curved fruit and three thick peel ribbons. Each ribbon has closed/open
// positions; the GPU blends them independently in both color and shadow passes.
enum BananaGeometry {
    static func center(_ t:Float)->SIMD3<Float> { [0.22*t*t,t,0] }
    static func radius(_ t:Float)->Float { 0.105*pow(max(0,sin(Float.pi*t)),0.35)+0.01 }
    static func fruit(_ u:Float,_ t:Float)->SIMD3<Float> {
        let angle=u*2*Float.pi
        let radial=normalize(SIMD3<Float>(1,-0.44*t,0))*cos(angle)+SIMD3<Float>(0,0,sin(angle))
        return center(t)+radial*radius(t)*(1+0.035*cos(5*angle))
    }
    static func mesh(_ kind:PropKind)->([PropVertex],[UInt32]) {
        var vertices:[PropVertex]=[],indices:[UInt32]=[]
        func patch(rows:Int,columns:Int,tag:Float,inside:Float,surface:(Float,Float,Bool)->SIMD3<Float>) {
            let base=UInt32(vertices.count)
            for row in 0...rows {for column in 0...columns {
                let u=Float(column)/Float(columns),v=Float(row)/Float(rows)
                func normal(_ open:Bool)->SIMD3<Float> {
                    let du=surface(u+0.0001,v,open)-surface(u-0.0001,v,open)
                    let dv=surface(u,min(1,v+0.0001),open)-surface(u,max(0,v-0.0001),open)
                    let n=cross(dv,du)
                    return length(n)>1e-9 ? normalize(n)*(inside>0.5 ? -1:1):SIMD3(0,1,0)
                }
                vertices.append(PropVertex(position:SIMD4(surface(u,v,false),1),normal:SIMD4(normal(false),0),uv:[u,v,tag,inside],openedPosition:SIMD4(surface(u,v,true),1),openedNormal:SIMD4(normal(true),0)))
                if row<rows && column<columns {
                    let a=base+UInt32(row*(columns+1)+column),b=a+UInt32(columns+1)
                    indices += inside>0.5 ? [a,a+1,b,a+1,b+1,b]:[a,b,a+1,a+1,b,b+1]
                }
            }}
        }
        if kind == .bananaFruit {
            patch(rows:48,columns:40,tag:0,inside:0) {u,t,_ in fruit(u,t)}
            // Separate cap normals retain a visible, flat bite surface as fruit shortens.
            for top in [false,true] {
                let base=UInt32(vertices.count),t:Float=top ? 1:0
                for i in 0...40 {
                    let u=Float(i)/40,p=fruit(u,t)
                    vertices.append(PropVertex(position:SIMD4(p,1),normal:[0,top ? 1:-1,0,0],uv:[u,1,top ? 1:2,0]))
                }
                vertices.append(PropVertex(position:SIMD4(center(t),1),normal:[0,top ? 1:-1,0,0],uv:[0,0,top ? 1:2,0]))
                for i in 0..<40 {indices += [base+UInt32(i),base+UInt32(i+1),base+41]}
            }
        } else {
            for strip in 0..<3 {
                let angle=Float(strip)*2*Float.pi/3
                func surface(_ u:Float,_ t:Float,_ open:Bool,_ inner:Bool)->SIMD3<Float> {
                    let a=angle+(u-0.5)*2*Float.pi/3
                    let radial=normalize(SIMD3<Float>(1,-0.44*t,0))*cos(a)+SIMD3<Float>(0,0,sin(a))
                    let thickness:Float=inner ? 0.004:0.016
                    let closed=center(t)+radial*(radius(t)+thickness)
                    guard open,t>0.24 else {return closed}
                    let q=(t-0.24)/0.76
                    let outward=SIMD3<Float>(cos(angle),0,sin(angle)),across=SIMD3<Float>(-sin(angle),0,cos(angle))
                    let spine=center(0.24)+outward*(radius(0.24)+0.45*sin(q*Float.pi/2))+SIMD3<Float>(0,0.24*sin(q*Float.pi)-0.38*q,0)
                    let width:Float=0.115*(1-0.78*q*q)
                    let shellNormal=normalize(outward*(0.38-0.24*Float.pi*cos(q*Float.pi))+SIMD3<Float>(0,0.45*Float.pi/2*cos(q*Float.pi/2),0))
                    let opened=spine+across*((u-0.5)*2*width)+shellNormal*(inner ? 0.006:-0.006)
                    let blend=RoutineLibrary.smooth(Double(q),0,0.20)
                    return closed+(opened-closed)*blend
                }
                for inner in [false,true] {
                    patch(rows:48,columns:16,tag:Float(strip),inside:inner ? 1:0) {u,t,open in surface(u,t,open,inner)}
                }
                // Close the long edges and tip: actual shell thickness remains visible in profile.
                for edge:Float in [0,1] {
                    patch(rows:48,columns:1,tag:Float(strip),inside:0) {w,t,open in
                        surface(edge,t,open,false)*(1-w)+surface(edge,t,open,true)*w
                    }
                }
                patch(rows:1,columns:16,tag:Float(strip),inside:0) {u,w,open in
                    surface(u,1,open,false)*(1-w)+surface(u,1,open,true)*w
                }
            }
        }
        return (vertices,indices)
    }
}
