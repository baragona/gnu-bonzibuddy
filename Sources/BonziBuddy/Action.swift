import Foundation

// Shared action catalog used by UI, choreography, and validation.
enum Action: String, CaseIterable {
    case idle = "Idle"
    case lookLeft = "Look Left", lookRight = "Look Right"
    case clap = "Clap", shrug = "Shrug", wave = "Wave"
    case dance = "Dance", think = "Think", surprised = "Surprised", speak = "Speak"
    case globe = "Globe", juggle = "Juggle"

    var duration: Double {
        switch self {
        case .idle, .speak: return .infinity
        case .lookLeft, .lookRight: return LookAnimation.duration
        case .clap: return ClapAnimation.duration
        case .shrug: return ShrugAnimation.duration
        case .dance: return 8
        case .globe: return 6.2
        case .juggle: return CoconutJuggle.duration
        case .wave, .think, .surprised: return 4
        }
    }
    var changesFacing: Bool { self == .globe }
}
