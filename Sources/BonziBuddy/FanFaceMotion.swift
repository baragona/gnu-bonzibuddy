import Foundation
import simd

// Automatic jaw and action eyelids. User overrides are applied afterward by Renderer.
final class FanFaceMotion {
    private var action:Action?
    private var started:Double?
    private var transitionTime:Double=0
    private var lastTime:Double = -.infinity
    private var from=FacialIntent()
    private var displayed=FacialIntent()
    static func target(_ action:Action,elapsed:Double)->FacialIntent {
        let elapsed=max(0,elapsed)
        let jaw:Float=action == .speak ? 0.3+0.25*sin(Float(elapsed)*12) : action == .surprised ? 0.6*min(1,Float(elapsed)*3)*min(1,Float(max(0,action.duration-elapsed))*3) : 0
        let closure:Float=action == .clap ? 1-ClapAnimation.eyeOpen(at:elapsed) : action == .shrug ? 1-ShrugAnimation.eyeOpen(at:elapsed) : 0
        let routine=RoutineLibrary.sample(action,at:elapsed)
        var face=routine.face
        face.jawOpening=max(jaw,face.jawOpening);face.eyeClosure=max(closure,face.eyeClosure)
        return face
    }
    func sample(_ next:Action,started nextStart:Double,at time:Double,elapsed:Double?=nil)->FacialIntent {
        // Offline previews can restart their timeline; the live clock is monotonic.
        if time<lastTime { action=nil;started=nil;displayed = FacialIntent() }
        if action != next || started != nextStart {
            from=displayed;transitionTime=time;action=next;started=nextStart
        }
        let t=min(1,max(0,Float((time-transitionTime)/0.15)))
        let weight=t*t*(3-2*t)
        displayed=from.blended(to:Self.target(next,elapsed:elapsed ?? (time-nextStart)),amount:weight)
        lastTime=time
        return displayed
    }
}
