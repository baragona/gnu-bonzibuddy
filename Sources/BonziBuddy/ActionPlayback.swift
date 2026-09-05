import Foundation

struct ActionSnapshot {
    let action:Action
    let started:Double
    let elapsed:Double
}

// Owns action selection and time. Sampling is read-only: drawing another camera
// or seeking backward cannot accidentally complete or replace the selected clip.
struct ActionPlayback {
    private var selected:Action = .idle
    private var started:Double=0
    mutating func play(_ action:Action,at time:Double) {selected=action;started=time}
    func sample(at time:Double)->ActionSnapshot {
        let elapsed=max(0,time-started)
        if elapsed>selected.duration {
            let finished=started+selected.duration
            return ActionSnapshot(action:.idle,started:finished,elapsed:max(0,time-finished))
        }
        return ActionSnapshot(action:selected,started:started,elapsed:elapsed)
    }
}
