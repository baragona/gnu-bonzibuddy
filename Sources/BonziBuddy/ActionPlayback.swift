import Foundation

enum PlaybackMode {case once, hold}
struct ActionSnapshot {
    let action:Action
    // Identifies a playback phase for interruption blends; elapsed can be looped.
    let started:Double
    let elapsed:Double
}

// Sampling is read-only. Hold-capable clips have authored entry, loop, and return
// ranges; requesting a return does not put scheduling logic into their samplers.
struct ActionPlayback {
    private var selected:Action = .idle
    private var started:Double=0
    private var mode:PlaybackMode = .once
    private var returnAt:Double?
    mutating func play(_ action:Action,at time:Double,mode:PlaybackMode = .once) {
        selected=action;started=time;self.mode=mode;returnAt=nil
    }
    @discardableResult mutating func finish(at time:Double)->Bool {
        guard let loop=RoutineLibrary.definitions[selected]?.holdRange else {return false}
        if returnAt != nil {return true}
        if mode == .once && time>=started+selected.duration {return false}
        // Finish putting the object on before starting its removal.
        returnAt=max(time,started+loop.lowerBound)
        return true
    }
    // Move the body timeline while an accessory owns the hand-transfer slot.
    mutating func shift(by duration:Double) {
        started += duration
        if let requested=returnAt {returnAt=requested+duration}
    }
    func sample(at time:Double)->ActionSnapshot {
        let elapsed=max(0,time-started)
        let loop=RoutineLibrary.definitions[selected]?.holdRange
        if let requested=returnAt,let loop,time>=requested {
            let returning=loop.upperBound+time-requested
            if returning>selected.duration {
                let finished=requested+selected.duration-loop.upperBound
                return ActionSnapshot(action:.idle,started:finished,elapsed:max(0,time-finished))
            }
            return ActionSnapshot(action:selected,started:requested,elapsed:returning)
        }
        if mode == .hold,let loop,elapsed>=loop.lowerBound {
            let wrapped=loop.lowerBound+(elapsed-loop.lowerBound).truncatingRemainder(dividingBy:loop.upperBound-loop.lowerBound)
            return ActionSnapshot(action:selected,started:started,elapsed:wrapped)
        }
        if elapsed>selected.duration {
            let finished=started+selected.duration
            return ActionSnapshot(action:.idle,started:finished,elapsed:max(0,time-finished))
        }
        return ActionSnapshot(action:selected,started:started,elapsed:elapsed)
    }
}
