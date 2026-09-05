import Foundation

// Accessory intent is independent of body actions. Transfers are atomic: finish
// the current handoff before reversing. Sampling never advances mutable state.
struct WearableDefinition {
    let action:Action
    let entryDuration:Double
    let returnStart:Double
    let duration:Double
    static let sunglasses=WearableDefinition(action:.sunglasses,entryDuration:SunglassesRoutine.holdRange.lowerBound,returnStart:SunglassesRoutine.holdRange.upperBound,duration:SunglassesRoutine.duration)
}
struct WearablePlayback {
    let definition:WearableDefinition
    init(definition:WearableDefinition) {self.definition=definition}
    struct Transfer {
        let definition:WearableDefinition
        let started:Double
        let enabled:Bool
        var duration:Double {enabled ? definition.entryDuration : definition.duration-definition.returnStart}
        var end:Double {started+duration}
        func snapshot(at time:Double)->ActionSnapshot {
            ActionSnapshot(action:definition.action,started:started,elapsed:(enabled ? 0:definition.returnStart)+max(0,time-started))
        }
    }
    private(set) var requested=false
    private var initial=false
    private var transfers:[Transfer]=[]
    var nextTransferStart:Double? {transfers.first?.started}
    var busyUntil:Double {transfers.last?.end ?? 0}
    func transfer(at time:Double)->Transfer? {transfers.first {time >= $0.started && time < $0.end}}
    func worn(at time:Double)->Bool {
        var worn=initial
        for transfer in transfers {
            if time<transfer.end {break}
            worn=transfer.enabled
        }
        return worn
    }
    mutating func setEnabled(_ enabled:Bool,at time:Double,beginAt:Double?=nil) {
        guard enabled != requested else {return}
        requested=enabled
        let current=transfer(at:time),settled=worn(at:time)
        initial=settled
        transfers=current.map {[$0]} ?? []
        let nextState=current?.enabled ?? settled
        if nextState != enabled {transfers.append(Transfer(definition:definition,started:current?.end ?? max(time,beginAt ?? time),enabled:enabled))}
    }
}
