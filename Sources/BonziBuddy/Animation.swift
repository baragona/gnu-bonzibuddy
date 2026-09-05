import Foundation
import simd

struct ArmPose {
    var elbow: SIMD3<Float>
    var wrist: SIMD3<Float>
    var angle: Float
    var palmTurn: Float = 0
    var spread: Float = 0
    static func rest(_ side:Float) -> ArmPose {
        ArmPose(elbow:[side*0.60,-0.24,0.02],wrist:[side*0.16,0.035-side*0.015,side > 0 ? 0.35 : 0.41],angle:-side * .pi/2)
    }
}

// Retargeted from sprite frames 40...50. These are hand-authored 3D poses;
// the reference pixels and third-party source are never loaded by the app.
enum ShrugAnimation {
    static let referenceFPS: Double = 15
    static let duration: Double = 33/referenceFPS
    static let returnStart: Double = 22/referenceFPS
    static func referenceFrame(at time:Double) -> Double {
        if time < returnStart { return min(10,max(0,time*referenceFPS)) }
        return max(0,10-(time-returnStart)*referenceFPS)
    }
    static func armFrame(_ frame:Int, side:Float) -> ArmPose {
        let rest=ArmPose.rest(side)
        switch frame {
        case 0...4: return rest
        case 5: return ArmPose(elbow:[side*0.57,-0.20,0.03],wrist:[side*0.20,0.14,0.29],angle:-side*2.2,palmTurn:side*0.2,spread:0.1)
        case 6: return ArmPose(elbow:[side*0.53,-0.18,0.02],wrist:[side*0.46,0.16,0.19],angle:-side*Float.pi,palmTurn:side*2.4,spread:0.45)
        case 7: return ArmPose(elbow:[side*0.59,-0.16,0.01],wrist:[side*0.83,0.065,0.14],angle:-side*4.05,palmTurn:side*3.0,spread:0.9)
        case 8: return ArmPose(elbow:[side*0.57,side > 0 ? -0.20 : -0.21,0.01],wrist:[side*0.94,side > 0 ? -0.04 : -0.035,0.13],angle:side > 0 ? -4.7 : 4.6,palmTurn:side*Float.pi,spread:1)
        case 9: return ArmPose(elbow:[side*0.57,side > 0 ? -0.105 : -0.145,0.01],wrist:[side*0.88,side > 0 ? 0.12 : 0.035,0.13],angle:side > 0 ? -4.55 : 4.83,palmTurn:side*Float.pi,spread:1)
        default: return ArmPose(elbow:[side*0.57,side > 0 ? -0.11 : -0.15,0.01],wrist:[side*0.88,side > 0 ? 0.11 : 0.025,0.13],angle:side > 0 ? -4.55 : 4.83,palmTurn:side*Float.pi,spread:1)
        }
    }
    static func cubic(_ p0:Float,_ p1:Float,_ p2:Float,_ p3:Float,_ t:Float) -> Float {
        0.5*((2*p1)+(-p0+p2)*t+(2*p0-5*p1+4*p2-p3)*t*t+(-p0+3*p1-3*p2+p3)*t*t*t)
    }
    static func arm(at time:Double,side:Float) -> ArmPose {
        let position=referenceFrame(at:time), i=Int(floor(position)), t=Float(position-Double(i))
        let keys=(-1...2).map { armFrame(min(10,max(0,i+$0)),side:side) }
        func scalar(_ value:(ArmPose)->Float) -> Float { cubic(value(keys[0]),value(keys[1]),value(keys[2]),value(keys[3]),t) }
        func vector(_ value:(ArmPose)->SIMD3<Float>) -> SIMD3<Float> { SIMD3((0..<3).map { c in scalar { value($0)[c] } }) }
        return ArmPose(elbow:vector { $0.elbow },wrist:vector { $0.wrist },angle:scalar { $0.angle },palmTurn:scalar { $0.palmTurn },spread:min(1,max(0,scalar { $0.spread })))
    }
    static func eyeOpen(at time:Double) -> Float {
        let values:[Float] = [1,1,0.4,0.12,0.65,1,1,1,1,1,1]
        let p=referenceFrame(at:time), i=Int(floor(p)), t=Float(p-Double(i))
        let k=(-1...2).map { values[min(10,max(0,i+$0))] }
        return min(1,max(0.12,cubic(k[0],k[1],k[2],k[3],t)))
    }
}

// The classic clap is an upper palm striking a lower, upturned palm.
// Source frames 13...15 repeat; the chosen repeat count is local app behavior.
enum ClapAnimation {
    static let fps:Double = 15
    static let frames = [10,11,12] + Array(repeating:[13,14,15],count:6).flatMap{$0} + [12,11,10]
    static let duration = Double(frames.count-1)/fps
    static func key(_ frame:Int,side:Float) -> ArmPose {
        let rest=ArmPose.rest(side)
        if frame==10 { return rest }
        if side<0 {
            let amount:Float=frame==11 ? 0.5 : 1
            return interpolate(rest,ArmPose(elbow:[-0.55,-0.22,0.04],wrist:[-0.16,-0.17,0.43],angle:.pi/2,palmTurn:-2.15,spread:0.3),amount)
        }
        switch frame {
        case 11: return ArmPose(elbow:[0.56,-0.22,0.04],wrist:[0.22,0.03,0.44],angle:-2.0,palmTurn:-0.5,spread:0.15)
        case 12,13: return ArmPose(elbow:[0.57,-0.22,0.04],wrist:[0.25,0.02,0.44],angle:-2.15,palmTurn:-1.0,spread:0.15)
        default: return ArmPose(elbow:[0.57,-0.22,0.04],wrist:[0.15,-0.078,0.49],angle:-.pi/2,palmTurn:-1.0,spread:0.3)
        }
    }
    static func interpolate(_ a:ArmPose,_ b:ArmPose,_ t:Float) -> ArmPose {
        ArmPose(elbow:mix(a.elbow,b.elbow,t:t),wrist:mix(a.wrist,b.wrist,t:t),angle:a.angle+(b.angle-a.angle)*t,palmTurn:a.palmTurn+(b.palmTurn-a.palmTurn)*t,spread:a.spread+(b.spread-a.spread)*t)
    }
    static func sample(_ time:Double) -> (Int,Int,Float) {
        let p=min(Double(frames.count-1),max(0,time*fps)),i=Int(p),t=Float(p-Double(i))
        return (frames[i],frames[min(i+1,frames.count-1)],t*t*(3-2*t))
    }
    static func arm(at time:Double,side:Float) -> ArmPose {
        let (a,b,t)=sample(time)
        return interpolate(key(a,side:side),key(b,side:side),t)
    }
    static func eyeOpen(at time:Double) -> Float {
        let (a,b,t)=sample(time)
        func value(_ frame:Int)->Float { frame==11 ? 0.12 : frame==10 ? 0.65 : 1 }
        return value(a)+(value(b)-value(a))*t
    }
}

// Close quickly, pause briefly, and reopen more slowly; sampled at display rate.
enum BlinkAnimation {
    static func eyeOpen(at time:Double) -> Float {
        let t=Float(max(0,time).truncatingRemainder(dividingBy:4.6))-4.0
        func ease(_ v:Float)->Float { let x=min(1,max(0,v)); return x*x*(3-2*x) }
        if t<0 { return 1 }
        if t<0.08 { return 1-ease(t/0.08) }
        if t<0.12 { return 0 }
        return ease((t-0.12)/0.16)
    }
}

// Reference sequences 143...146 and 149...152 turn the head independently.
enum LookAnimation {
    static let frames=[0,1,2,3]+Array(repeating:3,count:14)+[2,1,0]
    static let duration=Double(frames.count-1)/15
    static func yaw(at time:Double,left:Bool)->Float {
        let values:[Float]=left ? [0,-0.10,-0.26,-0.45] : [0,0.15,0.40,0.65]
        let position=min(Double(frames.count-1),max(0,time*15)),i=Int(position)
        let t=Float(position-Double(i)),weight=t*t*(3-2*t)
        let a=values[frames[i]],b=values[frames[min(i+1,frames.count-1)]]
        return a+(b-a)*weight
    }
}
