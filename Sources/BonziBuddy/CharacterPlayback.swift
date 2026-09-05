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
    private var accessories=WearablePlayback()
    var sunglassesEnabled:Bool {accessories.requested.contains(.sunglasses)}
    var headphonesEnabled:Bool {accessories.requested.contains(.headphones)}
    func playbackSnapshot(at time:Double)->ActionSnapshot {
        accessories.transfer(at:time)?.snapshot(at:time) ?? bodySnapshot(at:time)
    }
    func wears(_ wearable:Wearable,at time:Double)->Bool {
        accessories.transfer(at:time)?.wearable != wearable && accessories.worn(at:time).contains(wearable)
    }
    func wearsSunglasses(at time:Double)->Bool {wears(.sunglasses,at:time)}
    func accessoryPose(at time:Double)->RoutinePose {
        var pose=RoutinePose()
        for wearable in Wearable.allCases where wears(wearable,at:time) {
            let accessory=wearable.wornPose
            pose.props += accessory.props
            pose.face.eyeClosure=max(pose.face.eyeClosure,accessory.face.eyeClosure)
        }
        return pose
    }
    mutating func setSunglassesEnabled(_ enabled:Bool,at time:Double) {setWearableEnabled(.sunglasses,enabled,at:time)}
    mutating func setHeadphonesEnabled(_ enabled:Bool,at time:Double) {setWearableEnabled(.headphones,enabled,at:time)}
    mutating func setWearableEnabled(_ wearable:Wearable,_ enabled:Bool,at time:Double) {
        guard enabled != accessories.requested.contains(wearable) else {return}
        adoptQueuedBody(at:time)
        let previousEnd=max(time,accessories.busyUntil)
        let body=bodySnapshot(at:time)
        var begin=time
        if accessories.busyUntil<=time {
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
        } else if accessories.transfer(at:time)==nil {
            begin=accessories.nextTransferStart ?? time
        }
        accessories.setEnabled(wearable,enabled,at:time,beginAt:begin)
        let nextEnd=max(time,accessories.busyUntil)
        if suspendsBody {playback.shift(by:nextEnd-previousEnd)}
        if var queued=queuedBody {
            queued.player.shift(by:nextEnd-queued.start);queued.start=nextEnd;queuedBody=queued
        }
    }
    @discardableResult mutating func finishRoutine(at time:Double)->Bool {
        adoptQueuedBody(at:time)
        if accessories.busyUntil>time {play(.idle,at:time);return true}
        return playback.finish(at:time)
    }
    mutating func play(_ action: Action, at time: Double, mode:PlaybackMode = .once) {
        adoptQueuedBody(at:time)
        if accessories.busyUntil>time {
            var player=ActionPlayback();player.play(action,at:accessories.busyUntil,mode:mode)
            queuedBody=(player,accessories.busyUntil)
        } else {playback.play(action,at:time,mode:mode);queuedBody=nil}
    }
}
