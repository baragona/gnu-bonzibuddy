import simd

enum MailboxGeometry {
    static func mesh(_ kind:PropKind)->([PropVertex],[UInt32]) {
        var vertices:[PropVertex]=[],indices:[UInt32]=[]
        func patch(rows:Int,columns:Int,material:Float,flip:Bool=false,surface:(Float,Float)->SIMD3<Float>) {
            let base=UInt32(vertices.count)
            for row in 0...rows {for col in 0...columns {
                let u=Float(col)/Float(columns),v=Float(row)/Float(rows),p=surface(u,v)
                let du=surface(u+0.0001,v)-surface(u-0.0001,v),dv=surface(u,v+0.0001)-surface(u,v-0.0001)
                let n=normalize(cross(du,dv))*(flip ? -1:1)
                vertices.append(PropVertex(position:SIMD4(p,1),normal:SIMD4(n,0),uv:[u,v,0,material]))
                if row<rows && col<columns {
                    let a=base+UInt32(row*(columns+1)+col),b=a+UInt32(columns+1)
                    indices += flip ? [a,b,a+1,a+1,b,b+1]:[a,a+1,b,a+1,b+1,b]
                }
            }}
        }
        func disc(x:Float,centerY:Float,radius:Float,material:Float,normal:Float) {
            let base=UInt32(vertices.count)
            vertices.append(PropVertex(position:[x,centerY,0,1],normal:[normal,0,0,0],uv:[0.5,0.5,0,material]))
            for i in 0...48 {
                let a=Float(i)*2*Float.pi/48
                vertices.append(PropVertex(position:[x,centerY+radius*cos(a),radius*sin(a),1],normal:[normal,0,0,0],uv:[0.5+0.5*cos(a),0.5+0.5*sin(a),0,material]))
                if i<48 {let j=base+1+UInt32(i);indices += normal>0 ? [base,j,j+1]:[base,j+1,j]}
            }
        }
        if kind == .mailboxDoor {
            disc(x:0.012,centerY:0.155,radius:0.155,material:0,normal:1)
            disc(x:-0.012,centerY:0.155,radius:0.155,material:1,normal:-1)
            patch(rows:1,columns:48,material:2) {u,v in
                let a=u*2*Float.pi
                return [-0.012+0.024*v,0.155+0.155*cos(a),0.155*sin(a)]
            }
        } else {
            for inner in [false,true] {
                patch(rows:16,columns:64,material:inner ? 1:0,flip:inner) {u,v in
                    let a=u*2*Float.pi,x = -0.26+0.52*v
                    let ring=exp(-pow((x+0.12)/0.016,2))+exp(-pow((x-0.16)/0.016,2))
                    let r:Float=inner ? 0.132:0.16+0.009*ring
                    return [x,r*cos(a),r*sin(a)]
                }
            }
            disc(x:-0.263,centerY:0,radius:0.16,material:0,normal:-1)
            disc(x:-0.248,centerY:0,radius:0.132,material:1,normal:1)
            patch(rows:1,columns:64,material:2,flip:true) {u,v in
                let a=u*2*Float.pi,r=0.132+0.028*v
                return [0.26,r*cos(a),r*sin(a)]
            }
            patch(rows:32,columns:20,material:0,flip:true) {u,v in
                let a=u*2*Float.pi,y = -1.0+0.85*v,x=0.045*sin(v*7)
                let node=pow(0.5+0.5*cos(v*6*Float.pi),24)
                let r=0.036+0.011*node
                return [x+r*cos(a),y,r*sin(a)]
            }
            for side:Float in [-1,1] {
                patch(rows:12,columns:4,material:3) {u,v in
                    let width=0.001+0.044*sin(Float.pi*v)
                    return [side*(0.01+0.12*v),-1.0+0.24*v,0.025+(u-0.5)*2*width+0.04*sin(Float.pi*v)]
                }
            }
        }
        return (vertices,indices)
    }
}
