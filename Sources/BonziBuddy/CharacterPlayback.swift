import Foundation

// Coordinates independent body and accessory timelines without rendering state.
struct CharacterPlayback {
    private var playback=ActionPlayback()
    private var queuedBody:(player:ActionPlayback,start:Double)?
    private var suspendsBody=false
    private func bodySnapshot(at time:Double)->ActionSnapshot {
        if let queued=queuedBody,time>=queued.start {return queued.player.sample(at:time)}
        return playback.sample(at:time)
    }
    private mutating func adoptQueuedBody(at time:Double) {
        if let queued=queuedBody,time>=queued.start {playback=queued.player;queuedBody=nil}
    }
    private var sunglasses=WearablePlayback(definition:.sunglasses)
    var sunglassesEnabled:Bool {sunglasses.requested}
    func playbackSnapshot(at time:Double)->ActionSnapshot {
        sunglasses.transfer(at:time)?.snapshot(at:time) ?? bodySnapshot(at:time)
    }
    func wearsSunglasses(at time:Double)->Bool {sunglasses.transfer(at:time)==nil && sunglasses.worn(at:time)}
    func accessoryPose(at time:Double)->RoutinePose {
        guard wearsSunglasses(at:time) else {return RoutinePose()}
        return RoutinePose(face:FacialIntent(eyeClosure:0.45),props:[PropCue(id:"sunglasses",kind:.sunglasses,anchor:.attachment(.head,axes:.joint),offset:.zero)])
    }
    mutating func setSunglassesEnabled(_ enabled:Bool,at time:Double) {
        guard enabled != sunglasses.requested else {return}
        adoptQueuedBody(at:time)
        let previousEnd=max(time,sunglasses.busyUntil)
        let body=bodySnapshot(at:time)
        var begin=time
        if sunglasses.busyUntil<=time {
            // Prop routines own their hands until their authored stow completes.
            // Wearing glasses does not reserve anything; only a transfer waits.
            let ownsProps=RoutineLibrary.definitions[body.action]?.accessoryTransferPolicy == .finishRoutine
            if ownsProps && body.action.duration.isFinite {
                if let loop=RoutineLibrary.definitions[body.action]?.holdRange {
                    // A held routine needs its authored return before another
                    // accessory can claim the hands; it must not wait forever.
                    playback.finish(at:time)
                    let returning=playback.sample(at:time)
                    begin=returning.elapsed>=loop.upperBound
                        ? time+max(0,body.action.duration-returning.elapsed)
                        : time+max(0,loop.lowerBound-body.elapsed)+body.action.duration-loop.upperBound
                } else {begin=time+max(0,body.action.duration-body.elapsed)}
            }
            suspendsBody=begin==time
        } else if sunglasses.transfer(at:time)==nil {
            begin=sunglasses.nextTransferStart ?? time
        }
        sunglasses.setEnabled(enabled,at:time,beginAt:begin)
        let nextEnd=max(time,sunglasses.busyUntil)
        if suspendsBody {playback.shift(by:nextEnd-previousEnd)}
        if var queued=queuedBody {
            queued.player.shift(by:nextEnd-queued.start);queued.start=nextEnd;queuedBody=queued
        }
    }
    @discardableResult mutating func finishRoutine(at time:Double)->Bool {
        adoptQueuedBody(at:time)
        if sunglasses.busyUntil>time {play(.idle,at:time);return true}
        return playback.finish(at:time)
    }
    mutating func play(_ action: Action, at time: Double, mode:PlaybackMode = .once) {
        adoptQueuedBody(at:time)
        if sunglasses.busyUntil>time {
            var player=ActionPlayback();player.play(action,at:sunglasses.busyUntil,mode:mode)
            queuedBody=(player,sunglasses.busyUntil)
        } else {playback.play(action,at:time,mode:mode);queuedBody=nil}
    }
}
