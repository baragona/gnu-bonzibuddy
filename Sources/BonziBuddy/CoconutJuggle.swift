import Foundation
import simd

// Three-ball cascade. Release cadence and catch positions drive both hands and props.
// Flight follows parabolic arcs; the short hand dwell absorbs the catch and feeds the next throw.
enum CoconutJuggle {
    static let firstRelease=0.9, cadence=0.36, period=1.08, flight=0.83
    static let height:Float=1.24
    static let forwardArc:Float=0.55
    static let radius:Float=0.20
    static let duration=6.7
    static func side(_ ball:Int,_ cycle:Int)->Float { (ball+cycle)%2==0 ? 1:-1 }
    static func launch(_ side:Float)->SIMD3<Float> { [side*0.30,0.12,0.62] }
    static func catchPoint(_ side:Float)->SIMD3<Float> { [side*0.84,0.12,0.62] }
    static func airborne(side:Float,phase:Float)->SIMD3<Float> {
        let from=launch(side),to=catchPoint(-side)
        return from+(to-from)*phase+SIMD3(0,4*height*phase*(1-phase),4*forwardArc*phase*(1-phase))
    }
    static func dwell(side:Float,phase:Float)->SIMD3<Float> {
        let from=catchPoint(side),to=launch(side),dt=Float(period-flight)
        let incoming=SIMD3<Float>(side*1.14/Float(flight),-4*height/Float(flight),-4*forwardArc/Float(flight))*dt
        let outgoing=SIMD3<Float>(-side*1.14/Float(flight),4*height/Float(flight),4*forwardArc/Float(flight))*dt
        let u=phase,u2=u*u,u3=u2*u
        return (2*u3-3*u2+1)*from+(u3-2*u2+u)*incoming+(-2*u3+3*u2)*to+(u3-u2)*outgoing
    }
    static func handCenter(side:Float,at t:Double)->SIMD3<Float> {
        let offset=firstRelease+(side>0 ? 0:cadence)
        let phase=(t-offset).truncatingRemainder(dividingBy:cadence*2)
        let p=phase<0 ? phase+cadence*2:phase
        let catchTime=cadence*2-(period-flight)
        if p>=catchTime {return dwell(side:side,phase:Float((p-catchTime)/(period-flight)))}
        // Follow through with the release velocity, then prepare the next catch.
        // Both joins with the loaded dwell preserve velocity as well as position.
        let settle=0.08
        let outgoing=SIMD3<Float>(-side*1.14/Float(flight),4*height/Float(flight),4*forwardArc/Float(flight))
        let incoming=SIMD3<Float>(side*1.14/Float(flight),-4*height/Float(flight),-4*forwardArc/Float(flight))
        if p<settle {
            let x=Float(p),h=Float(settle)
            return launch(side)+outgoing*(x-x*x/(2*h))
        }
        let ready=catchPoint(side)-incoming*Float(settle/2)
        if p>catchTime-settle {
            let x=Float(p-(catchTime-settle))
            return ready+incoming*(x*x/Float(2*settle))
        }
        let follow=launch(side)+outgoing*Float(settle/2)
        return follow+(ready-follow)*RoutineLibrary.smooth(p,settle,catchTime-settle)
    }
    static func sample(at t:Double)->RoutinePose {
        let engagement=RoutineLibrary.smooth(t,0,0.7)*(1-RoutineLibrary.smooth(t,6.0,duration))
        var hands:[HandSide:HandIntent]=[:]
        for side:Float in [-1,1] {
            let finalCatch=side>0 ? 5.69:5.33
            var center=handCenter(side:side,at:max(firstRelease,t))
            if t>=finalCatch {
                // Absorb the final catch before returning to rest, without another throw.
                let x=Float(min(0.08,t-finalCatch))
                let incoming=SIMD3<Float>(side*1.14/Float(flight),-4*height/Float(flight),-4*forwardArc/Float(flight))
                center=catchPoint(side)+incoming*(x-x*x/0.16)
            }
            let epoch=firstRelease+(side>0 ? 0:cadence)
            let phase=max(0,t-epoch).truncatingRemainder(dividingBy:cadence*2)
            let freeHand=t>=(side>0 ? firstRelease+cadence*2:epoch) && t<finalCatch
            let flourish:Float=freeHand ? RoutineLibrary.smooth(phase,0,0.08)*(1-RoutineLibrary.smooth(phase,0.25,0.47)):0
            let fingers=SIMD3<Float>(-side*0.65,0.15,0.3)*(1-flourish)+SIMD3<Float>(0,1,0)*flourish
            let palm=SIMD3<Float>(0,1,0)*(1-flourish)+SIMD3<Float>(0,0,1)*flourish
            hands[HandSide(sign:side)]=HandIntent(wrist:center-[0,radius,0],fingers:fingers,palm:palm,openness:0.8+0.2*flourish,weight:engagement)
        }
        let reveal=RoutineLibrary.smooth(t,0.35,0.65)*(1-RoutineLibrary.smooth(t,5.95,6.25))
        var props:[PropCue]=[]
        for ball in 0..<3 {
            let start=firstRelease+Double(ball)*cadence
            let elapsed=t-start
            let cycle=max(0,min(3,Int(floor(elapsed/period))))
            let local=elapsed-Double(cycle)*period
            let direction=side(ball,cycle)
            var anchor:PropAnchor = .character
            var position:SIMD3<Float>
            if elapsed<0 {
                anchor = .attachment(.wrist(HandSide(sign:side(ball,0))))
                position=ball==2 ? [-0.48,radius,0]:[0,radius,0]
                if ball==2 {
                    let gather=RoutineLibrary.smooth(t,firstRelease+0.04,firstRelease+0.24)
                    position += (SIMD3<Float>(0,radius,0)-position)*gather
                }
            } else if local<flight {
                position=airborne(side:direction,phase:Float(local/flight))
            } else {
                anchor = .attachment(.wrist(HandSide(sign:-direction)))
                position=[0,radius,0]
                if cycle==3 && ball==0 {
                    // Make room in the catching hand for the final coconut.
                    position += SIMD3(-0.48,0,0)*RoutineLibrary.smooth(t,5.0,5.5)
                }
            }
            let spin=Float(min(max(0,elapsed),3*period+flight))*4
            let rotation=simd_quatf(angle:spin,axis:normalize(SIMD3<Float>(0.3,1,0.5)))
            props.append(PropCue(id:"juggle.\(ball)",kind:.coconut,anchor:anchor,offset:position,rotation:rotation,scale:SIMD3(repeating:radius),visibility:reveal))
        }
        return RoutinePose(hands:hands,headTilt:0.025*sin(Float(t)*4)*engagement,face:FacialIntent(gaze:[0,0.28*engagement]),props:reveal>0 ? props:[])
    }
}
