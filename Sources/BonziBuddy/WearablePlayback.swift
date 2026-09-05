import Foundation

// The catalog describes persistent appearance separately from the reference
// performance. Wearing an accessory consumes no body or facial animation slot.
enum Wearable:CaseIterable {
    case sunglasses,headphones
    var definition:WearableDefinition {
        switch self {
        case .sunglasses: return WearableDefinition(action:.sunglasses,entryDuration:SunglassesRoutine.holdRange.lowerBound,returnStart:SunglassesRoutine.holdRange.upperBound,duration:SunglassesRoutine.duration)
        case .headphones: return WearableDefinition(action:.headphones,entryDuration:HeadphonesRoutine.holdRange.lowerBound,returnStart:HeadphonesRoutine.holdRange.upperBound,duration:HeadphonesRoutine.duration)
        }
    }
    var wornPose:RoutinePose {
        switch self {
        case .sunglasses: return RoutinePose(face:FacialIntent(eyeClosure:0.45),props:[PropCue(id:"sunglasses",kind:.sunglasses,anchor:.attachment(.head,axes:.joint),offset:.zero)])
        case .headphones: return RoutinePose(props:[PropCue(id:"headphones",kind:.headphones,anchor:.attachment(.head,axes:.joint),offset:.zero)])
        }
    }
}
struct WearableDefinition {
    let action:Action
    let entryDuration:Double
    let returnStart:Double
    let duration:Double
}

// One shared transfer queue arbitrates hands across accessories. An active
// handoff is atomic; pending transfers are rebuilt from the latest requested set.
// The queue is bounded by the catalog size plus one active transfer.
struct WearablePlayback {
    struct Transfer {
        let wearable:Wearable
        let started:Double
        let enabled:Bool
        var definition:WearableDefinition {wearable.definition}
        var duration:Double {enabled ? definition.entryDuration : definition.duration-definition.returnStart}
        var end:Double {started+duration}
        func snapshot(at time:Double)->ActionSnapshot {
            ActionSnapshot(action:definition.action,started:started,elapsed:(enabled ? 0:definition.returnStart)+max(0,time-started))
        }
    }
    private(set) var requested:Set<Wearable>=[]
    private var initial:Set<Wearable>=[]
    private var transfers:[Transfer]=[]
    var nextTransferStart:Double? {transfers.first?.started}
    var busyUntil:Double {transfers.last?.end ?? 0}
    func transfer(at time:Double)->Transfer? {transfers.first {time >= $0.started && time < $0.end}}
    func worn(at time:Double)->Set<Wearable> {
        var worn=initial
        for transfer in transfers {
            if time<transfer.end {break}
            if transfer.enabled {worn.insert(transfer.wearable)} else {worn.remove(transfer.wearable)}
        }
        return worn
    }
    mutating func setEnabled(_ wearable:Wearable,_ enabled:Bool,at time:Double,beginAt:Double?=nil) {
        guard enabled != requested.contains(wearable) else {return}
        if enabled {requested.insert(wearable)} else {requested.remove(wearable)}
        let current=transfer(at:time),settled=worn(at:time)
        initial=settled
        transfers=current.map {[$0]} ?? []
        var planned=settled
        if let current {
            if current.enabled {planned.insert(current.wearable)} else {planned.remove(current.wearable)}
        }
        var start=current?.end ?? max(time,beginAt ?? time)
        for accessory in Wearable.allCases where requested.contains(accessory) != planned.contains(accessory) {
            let next=Transfer(wearable:accessory,started:start,enabled:requested.contains(accessory))
            transfers.append(next);start=next.end
        }
    }
}
