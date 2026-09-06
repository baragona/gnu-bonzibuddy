import simd

struct AuditBounds {
    var lo=SIMD3<Float>(repeating:.infinity),hi=SIMD3<Float>(repeating:-.infinity)
    mutating func include(_ p:SIMD3<Float>) {lo=simd_min(lo,p);hi=simd_max(hi,p)}
    mutating func include(_ b:AuditBounds) {lo=simd_min(lo,b.lo);hi=simd_max(hi,b.hi)}
    func overlaps(_ b:AuditBounds)->Bool {lo.x<=b.hi.x && hi.x>=b.lo.x && lo.y<=b.hi.y && hi.y>=b.lo.y && lo.z<=b.hi.z && hi.z>=b.lo.z}
}
struct AuditTriangle {
    let a:SIMD3<Float>,b:SIMD3<Float>,c:SIMD3<Float>
    var bounds:AuditBounds {var b=AuditBounds();b.include(a);b.include(self.b);b.include(c);return b}
    var center:SIMD3<Float> {(a+b+c)/3}
    // Non-coplanar surface crossings. Tangencies and coplanar contact are excluded.
    func crossings(_ other:AuditTriangle)->[SIMD3<Float>] {
        func hit(_ from:SIMD3<Float>,_ to:SIMD3<Float>,_ t:AuditTriangle)->SIMD3<Float>? {
            let direction=to-from,e1=t.b-t.a,e2=t.c-t.a,h=cross(direction,e2),det=dot(e1,h)
            if abs(det)<1e-12 {return nil}
            let s=from-t.a,u=dot(s,h)/det
            if u < -1e-5 || u>1.00001 {return nil}
            let q=cross(s,e1),v=dot(direction,q)/det,d=dot(e2,q)/det
            if v < -1e-5 || u+v>1.00001 || d<0 || d>1 {return nil}
            return from+direction*d
        }
        var points:[SIMD3<Float>]=[]
        for (from,to,t) in [(a,b,other),(b,c,other),(c,a,other),(other.a,other.b,self),(other.b,other.c,self),(other.c,other.a,self)] {
            if let p=hit(from,to,t),!points.contains(where:{length_squared($0-p)<1e-10}) {points.append(p)}
        }
        return points.count>=2 ? points:[]
    }
}

// Topology is built once from the bind pose, then bounds refit to GPU positions.
final class AuditBVH {
    struct Node {var bounds=AuditBounds();var left = -1,right = -1;var ids:[Int]=[]}
    let indices:[SIMD3<Int>]
    private var nodes:[Node]=[]
    private(set) var triangles:[AuditTriangle]=[]
    init(indices:[SIMD3<Int>],points:[SIMD3<Float>]) {
        self.indices=indices
        triangles=indices.map {AuditTriangle(a:points[$0.x],b:points[$0.y],c:points[$0.z])}
        func build(_ ids:[Int])->Int {
            let index=nodes.count;nodes.append(Node())
            var bounds=AuditBounds();for id in ids {bounds.include(triangles[id].bounds)}
            nodes[index].bounds=bounds
            if ids.count<=12 {nodes[index].ids=ids;return index}
            let span=bounds.hi-bounds.lo,axis=span.x>span.y ? (span.x>span.z ? 0:2):(span.y>span.z ? 1:2)
            let sorted=ids.sorted {triangles[$0].center[axis]<triangles[$1].center[axis]},mid=sorted.count/2
            let l=build(Array(sorted[..<mid])),r=build(Array(sorted[mid...]))
            nodes[index].left=l;nodes[index].right=r;return index
        }
        if !indices.isEmpty {_=build(Array(indices.indices))}
    }
    func refit(_ points:[SIMD3<Float>]) {
        triangles=indices.map {AuditTriangle(a:points[$0.x],b:points[$0.y],c:points[$0.z])}
        for i in nodes.indices.reversed() {
            var bounds=AuditBounds()
            if nodes[i].left>=0 {bounds.include(nodes[nodes[i].left].bounds);bounds.include(nodes[nodes[i].right].bounds)}
            else {for id in nodes[i].ids {bounds.include(triangles[id].bounds)}}
            nodes[i].bounds=bounds
        }
    }
    func crossings(_ triangle:AuditTriangle,visit:([SIMD3<Float>])->Void) {
        guard !nodes.isEmpty else {return}
        let bounds=triangle.bounds
        var stack=[0]
        while let index=stack.popLast() {
            let node=nodes[index]
            if !bounds.overlaps(node.bounds) {continue}
            if node.left>=0 {stack.append(node.left);stack.append(node.right)}
            else {for id in node.ids where bounds.overlaps(triangles[id].bounds) {
                let points=triangle.crossings(triangles[id]);if !points.isEmpty {visit(points)}
            }}
        }
    }
}

func auditGeometrySelfCheck() throws {
    let surface=AuditTriangle(a:[0,0,0],b:[1,0,0],c:[0,1,0])
    let crossing=AuditTriangle(a:[0.25,0.1,-1],b:[0.25,0.1,1],c:[0.25,0.8,0])
    guard surface.crossings(crossing).count>=2,surface.crossings(surface).isEmpty else {throw failure("Audit triangle crossing/coplanar contract failed")}
    var points:[SIMD3<Float>]=[],indices:[SIMD3<Int>]=[]
    for i in 0..<40 {
        let start=points.count,offset=SIMD3<Float>(Float(i)*2,0,0)
        points += [surface.a+offset,surface.b+offset,surface.c+offset]
        indices.append([start,start+1,start+2])
    }
    let bvh=AuditBVH(indices:indices,points:points)
    func count(_ query:AuditTriangle)->Int {var hits=0;bvh.crossings(query){_ in hits+=1};return hits}
    guard count(crossing)==1 else {throw failure("Audit BVH missed known crossing")}
    bvh.refit(points.map {$0+SIMD3<Float>(0,0,5)})
    guard count(crossing)==0 else {throw failure("Audit BVH retained stale bounds")}
    let shifted=AuditTriangle(a:crossing.a+[0,0,5],b:crossing.b+[0,0,5],c:crossing.c+[0,0,5])
    guard count(shifted)==1 else {throw failure("Audit BVH refit missed moved geometry")}
}
