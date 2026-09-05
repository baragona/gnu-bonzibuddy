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
        var begin=time
        if accessories.busyUntil<=time {
            // Prop routines own their hands until their authored stow completes.
            // Wearing glasses does not reserve anything; only a transfer waits.
            begin=handoffTime(at:time)
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
    // Interactive requests honor authored stow/stand sequences. Direct play is
    // retained for deterministic previews and immediate speech synchronization.
    private mutating func handoffTime(at time:Double)->Double {
        let body=bodySnapshot(at:time)
        guard RoutineLibrary.definitions[body.action]?.handoffPolicy == .finishRoutine,body.action.duration.isFinite else {return time}
        if RoutineLibrary.definitions[body.action]?.holdRange != nil {
            playback.finish(at:time)
            return max(time,playback.completionTime ?? time)
        }
        return time+max(0,body.action.duration-body.elapsed)
    }
    mutating func request(_ action:Action,at time:Double,mode:PlaybackMode = .once) {
        adoptQueuedBody(at:time)
        if accessories.busyUntil>time {play(action,at:time,mode:mode);return}
        let body=bodySnapshot(at:time)
        if let source=RoutineLibrary.definitions[body.action]?.continuation,
           let destination=RoutineLibrary.definitions[action]?.continuation,
           source.family == destination.family,source.acceptsFrom.contains(body.elapsed) {
            let ready=time+max(0,source.delay(body.elapsed))
            if let exit=source.exitElapsed(body.elapsed) {
                playback.play(body.action,at:time,mode:.once,elapsed:exit)
            }
            var player=ActionPlayback()
            player.play(action,at:ready,mode:mode,elapsed:destination.entryElapsed)
            queuedBody=(player,ready)
            return
        }
        let ready=handoffTime(at:time)
        if ready>time {
            var player=ActionPlayback();player.play(action,at:ready,mode:mode)
            queuedBody=(player,ready)
        } else {play(action,at:time,mode:mode)}
    }
    @discardableResult mutating func finishRoutine(at time:Double)->Bool {
        adoptQueuedBody(at:time)
        if accessories.busyUntil>time {play(.idle,at:time);return true}
        queuedBody=nil
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
