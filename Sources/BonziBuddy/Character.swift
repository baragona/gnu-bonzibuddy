import simd
import Foundation

func translation(_ p: SIMD3<Float>) -> simd_float4x4 { var m = matrix_identity_float4x4; m.columns.3 = SIMD4(p,1); return m }
func scale(_ p: SIMD3<Float>) -> simd_float4x4 { simd_float4x4(diagonal: SIMD4(p,1)) }
func rotate(_ angle: Float, _ axis: SIMD3<Float> = [0,0,1]) -> simd_float4x4 { simd_float4x4(simd_quatf(angle: angle, axis: axis)) }
enum SurfaceKind { case skin, detail, nose, mouth, lid }
struct Instance { var model: simd_float4x4; var color: SIMD4<Float> }

final class Character {
    private var playback=ActionPlayback()
    func playbackSnapshot(at time:Double)->ActionSnapshot {playback.sample(at:time)}
    var yaw: Float = 0
    var pitch: Float = 0.18
    var bindPose = false
    private(set) var headBoneStart = 0
    private(set) var mouthOpening: Float = 0
    private(set) var palmBones: [Int] = []
    private(set) var armBones: [Int] = []
    private(set) var footBones: [Int] = []
    private(set) var browBones: [Int] = []
    private(set) var surfaces: [SurfaceKind] = []
    private var transitionMouth: Float = 0
    private var transitionFrom: [Instance] = []
    func play(_ action: Action, at time: Double) {
        let previous = localInstances(at:time)
        playback.play(action,at:time); transitionFrom = previous; transitionMouth = mouthOpening
    }
    func instances(at time: Double) -> [Instance] {
        var pose=localInstances(at:time)
        let orientation=rotate(bindPose ? 0 : pitch,[1,0,0])*rotate(yaw,[0,1,0])
        for i in pose.indices { pose[i].model=orientation*pose[i].model }
        return pose
    }
    // Capture and blend poses in character space; camera changes apply afterward.
    private func localInstances(at time: Double) -> [Instance] {
        let snapshot=playback.sample(at:time)
        let action=snapshot.action,elapsed=snapshot.elapsed
        let t = Float(time), a = Float(elapsed)
        let envelope = min(1, a*4) * min(1, Float(max(0,action.duration-elapsed))*3)
        let dance: Float = action == .dance ? sin(a*7)*envelope : 0
        let breath = 0.004*sin(t*2)
        let bob = abs(dance)*0.06
        let root = translation([0,bob,0]) * rotate(dance*0.07)
        var result: [Instance] = []
        surfaces.removeAll(keepingCapacity:true)
        browBones.removeAll(keepingCapacity:true)
        palmBones.removeAll(keepingCapacity:true)
        armBones.removeAll(keepingCapacity:true)
        footBones.removeAll(keepingCapacity:true)
        let fur: SIMD4<Float> = [0.53,0.305,0.76,1]
        let light: SIMD4<Float> = [0.757,0.620,0.889,1]
        let muzzle: SIMD4<Float> = [0.94,0.78,1.07,1]
        let dark: SIMD4<Float> = [0.16,0.065,0.23,1]
        let white: SIMD4<Float> = [0.95,0.94,0.91,1]
        func ellipsoid(_ p: SIMD3<Float>, _ s: SIMD3<Float>, _ c: SIMD4<Float>, _ parent: simd_float4x4 = matrix_identity_float4x4, _ angle: Float = 0, surface: SurfaceKind = .skin, grounded:Bool = false, breathWeight:Float = 1) {
            if grounded { footBones.append(result.count) }
            result.append(Instance(model: root * translation([0,grounded ? 0 : breath*breathWeight,0]) * parent * translation(p) * rotate(angle) * scale(s), color: c))
            surfaces.append(surface)
        }
        // Breath expands the torso subtly around its center; feet stay grounded.
        let torsoBreath = scale([1+breath*1.5,1,1+breath*2])
        // Broad pear-shaped trunk and pale, inset belly.
        ellipsoid([0,-0.105,0], [0.45,0.39,0.30], fur, torsoBreath)
        ellipsoid([0,-0.195,0.16], [0.38,0.29,0.20], light, torsoBreath)
        ellipsoid([0,0.12,0.0], [0.285,0.20,0.245], fur, torsoBreath)
        for side: Float in [-1,1] {
            let leg = translation([side*0.27,-0.48,0]) * rotate(-side*0.18+dance*0.1)
            ellipsoid([0,-0.065,0], [0.170,0.19,0.17], fur, leg, breathWeight:0.35)
            ellipsoid([0,-0.245,0.035], [0.090,0.12,0.10], fur, leg, breathWeight:0.08)
            let foot = translation([side*0.30,-0.85,0.12]) * rotate(side*0.45,[0,1,0])
            ellipsoid([0,0.025,0.005],[0.130,0.075,0.21],fur,foot,grounded:true)
            for digit in 0..<4 {
                ellipsoid([Float(digit)*0.052-0.078,-0.025,0.18],[0.031,0.028,0.12-Float(abs(digit-1))*0.013],fur,foot,grounded:true)
            }
            func limb(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ radius: Float) {
                armBones.append(result.count)
                let delta = b-a
                let orientation = simd_float4x4(simd_quatf(from: SIMD3<Float>(0,1,0), to: normalize(delta)))
                result.append(Instance(model: root * translation([0,breath,0]) * translation((a+b)/2) * orientation * scale([radius,length(delta)/2+radius*0.35,radius]),color:fur))
                surfaces.append(.skin)
            }
            let shoulder = SIMD3<Float>(side*0.20,0.10,0)
            let resting = ArmPose.rest(side)
            let restElbow = resting.elbow
            let restWrist = resting.wrist
            var targetElbow = restElbow, targetWrist = restWrist
            var handAngle: Float = -side * .pi/2
            var palmTurn: Float = 0
            var fingerSpread: Float = 0
            if bindPose {
                targetElbow = [side*0.67,-0.16,0]
                targetWrist = [side*0.96,-0.49,0.04]
                handAngle = side*0.55
            } else if action == .clap {
                let pose = ClapAnimation.arm(at:elapsed,side:side)
                targetElbow=pose.elbow; targetWrist=pose.wrist
                handAngle=pose.angle; palmTurn=pose.palmTurn; fingerSpread=pose.spread
            } else if action == .shrug {
                let pose = ShrugAnimation.arm(at:elapsed,side:side)
                targetElbow=pose.elbow; targetWrist=pose.wrist
                handAngle=pose.angle; palmTurn=pose.palmTurn; fingerSpread=pose.spread
            } else if action == .wave && side == 1 {
                targetElbow = [0.67,0.23,0.02]
                // The wrist stays planted while the hand rotates around its base.
                targetWrist = [0.74,0.67,0.08]
                handAngle = -.pi + 0.30*sin(a*8)
                palmTurn = .pi * envelope
                fingerSpread = 0.45 * envelope
            } else if action == .surprised {
                targetElbow = [side*0.58,0.39,0]
                targetWrist = [side*0.63,0.83,0.04]
                handAngle = side * .pi
            } else if action == .dance {
                targetElbow = [side*0.61,0.05+0.13*sin(a*6+side),0]
                targetWrist = [side*0.93,0.2+0.23*sin(a*6+side),0.1]
                handAngle = side*1.7
            } else if action == .think && side == 1 {
                targetElbow = [0.52,-0.1,0.09]
                targetWrist = [0.18,0.30,0.38]
                handAngle = 2.8
            }
            let blend: Float = bindPose || action == .shrug || action == .clap ? 1 : envelope*envelope*(3-2*envelope)
            let elbow = mix(restElbow,targetElbow,t:blend), wrist = mix(restWrist,targetWrist,t:blend)
            handAngle = -side * .pi/2 + blend*(handAngle+side * .pi/2)
            limb(shoulder,elbow,0.10-fingerSpread*0.01); limb(elbow,wrist,0.087)
            let hand = translation(wrist) * rotate(handAngle) * rotate(palmTurn,[0,1,0])
            let palmWidth:Float = 0.82+0.18*fingerSpread
            palmBones.append(result.count)
            ellipsoid([0,-0.10-fingerSpread*0.04,0],[0.102*palmWidth,0.10+fingerSpread*0.055,0.055],fur,hand)
            for digit in 0..<4 {
                ellipsoid([(Float(digit)*0.037-0.0555)*palmWidth,-0.205-fingerSpread*0.15,0.015],[0.021,0.065+fingerSpread*0.085-Float(abs(digit-1))*0.008,0.02],light,hand,Float(digit-1)*(0.08+fingerSpread*0.17))
            }
            ellipsoid([-side*(0.095+fingerSpread*0.045)*palmWidth,-0.10-fingerSpread*0.085,0.01],[0.025,0.05+fingerSpread*0.05,0.025],light,hand,-side*0.5)
        }
        headBoneStart = result.count
        let looking = action == .lookLeft || action == .lookRight
        let headYaw:Float = looking ? LookAnimation.yaw(at:elapsed,left:action == .lookLeft) : 0
        let head = translation([0.01,0.56,0.015]) * rotate(headYaw,[0,1,0]) * rotate(0.018*sin(t*1.5)+dance*0.07 + (action == .think ? envelope*0.12 : 0))
        ellipsoid([0,0.03,0.02], [0.265,0.37,0.215], fur, head)
        ellipsoid([0,0.28,-0.025], [0.11,0.11,0.13], fur, head)
        for side: Float in [-1,1] {
            ellipsoid([side*0.305,-0.05,0], [0.05,0.045,0.055], fur, head)
            ellipsoid([side*0.310,-0.05,0.052], [0.03,0.032,0.021], light, head)
        }
        ellipsoid([0,-0.16,0.115], [0.280,0.19,0.18], light, head)
        for side: Float in [-1,1] { ellipsoid([side*0.16,-0.075,0.20],[0.151,0.145,0.13],muzzle,head) }
        // Fill the upper muzzle between the cheeks, tapering down toward the smile.
        ellipsoid([0,-0.12,0.22],[0.20,0.16,0.10],muzzle,head)
        let talking = action == .speak ? (0.5+0.5*sin(a*17))*0.07*envelope : 0
        mouthOpening = talking
        ellipsoid([0,-0.20,0.21], [0.24,0.065+talking,0.028], [0.48,0.31,0.62,1], head, surface:.mouth)
        ellipsoid([0,-0.195, 0.18+min(1,talking/0.04)*0.13], [0.18,0.018,0.009], white, head, surface:.detail)
        ellipsoid([0,-0.255-talking*0.6,0.15], [0.18,0.012,0.018], muzzle, head)
        ellipsoid([0,0.025,0.30], [0.082,0.040,0.08], [0.58,0.33,0.74,1], head, surface:.nose)
        for side: Float in [-1,1] { ellipsoid([side*0.037,0.001,0.37], [0.006,0.004,0.005], [0.25,0.13,0.35,1], head, surface:.detail) }
        let blink = action == .clap ? ClapAnimation.eyeOpen(at:elapsed) : action == .shrug ? ShrugAnimation.eyeOpen(at:elapsed) : BlinkAnimation.eyeOpen(at:time)
        for side: Float in [-1,1] {
            ellipsoid([side*0.103,0.115,0.18], [0.103,0.140,0.080], light, head)
            ellipsoid([side*0.098,0.12,0.235], [0.085,0.115,0.039], white, head, surface:.detail)
            ellipsoid([side*0.072,0.127,0.271], [0.035,0.045,0.018], dark, head, surface:.detail)
            ellipsoid([side*0.072-0.011,0.144,0.287], [0.012,0.016,0.006], white, head, surface:.detail)
            // Lid color alpha carries openness to Metal; the mesh itself is opaque.
            ellipsoid([side*0.098,0.12,0.234], [0.090,0.120,0.067], [fur.x,fur.y,fur.z,blink], head, surface:.lid)
            browBones.append(result.count)
            ellipsoid([side*0.105,0.25,0.190], [0.085,0.028,0.025], fur, head, -side*0.12)
        }
        let transitionDuration:Float = action == .clap || looking ? 0.10 : 0.25
        if !bindPose && a < transitionDuration && transitionFrom.count == result.count {
            let linear = a/transitionDuration, weight = linear*linear*(3-2*linear)
            mouthOpening = transitionMouth+(mouthOpening-transitionMouth)*weight
            for i in result.indices {
                result[i].model = blendedTransform(transitionFrom[i].model,result[i].model,weight)
                if surfaces[i] == .lid { result[i].color.w = transitionFrom[i].color.w+(result[i].color.w-transitionFrom[i].color.w)*weight }
            }
        }
        return result
    }
}

func mix(_ a: SIMD3<Float>, _ b: SIMD3<Float>, t: Float) -> SIMD3<Float> { a+(b-a)*t }

func blendedTransform(_ a:simd_float4x4,_ b:simd_float4x4,_ t:Float) -> simd_float4x4 {
    func decompose(_ m:simd_float4x4) -> (SIMD3<Float>,simd_quatf,SIMD3<Float>) {
        let s = SIMD3<Float>(length(m.columns.0),length(m.columns.1),length(m.columns.2))
        let r = simd_float3x3(columns:(SIMD3(m.columns.0.x,m.columns.0.y,m.columns.0.z)/s.x,SIMD3(m.columns.1.x,m.columns.1.y,m.columns.1.z)/s.y,SIMD3(m.columns.2.x,m.columns.2.y,m.columns.2.z)/s.z))
        return (SIMD3(m.columns.3.x,m.columns.3.y,m.columns.3.z),simd_quatf(r),s)
    }
    let x = decompose(a), y = decompose(b)
    return translation(mix(x.0,y.0,t:t))*simd_float4x4(simd_slerp(x.1,y.1,t))*scale(mix(x.2,y.2,t:t))
}
