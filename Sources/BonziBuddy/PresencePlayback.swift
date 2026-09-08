import Foundation

// Presence is independent of body and accessory pose. Sampling never consumes
// a completion event, so an offline seek cannot resurrect a hidden character.
struct PresencePlayback {
    private struct Change {let time:Double;let visible:Bool}
    private var changes:[Change]=[]
    private(set) var requestedVisible=true
    private(set) var entranceEnds:Double?
    func isVisible(at time:Double)->Bool {changes.last(where:{$0.time<=time})?.visible ?? true}
    func visibleSince(at time:Double)->Double? {changes.last(where:{$0.time<=time && $0.visible})?.time}
    func nextChange(after time:Double)->Double? {changes.first(where:{$0.time>time})?.time}
    mutating func schedule(_ visible:Bool,requestedAt time:Double,effectiveAt boundary:Double,entranceEnds:Double?=nil) {
        precondition(time.isFinite && boundary.isFinite && boundary>=time)
        changes.removeAll(where:{$0.time>time})
        let current=isVisible(at:time)
        if current != visible || boundary>time {changes.append(Change(time:boundary,visible:visible))}
        requestedVisible=visible;self.entranceEnds=entranceEnds
    }
}
