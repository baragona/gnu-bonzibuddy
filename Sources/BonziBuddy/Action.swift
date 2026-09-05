import Foundation

// Shared action catalog used by UI, choreography, and validation.
enum Action: String, CaseIterable {
    case idle = "Idle"
    case lookLeft = "Look Left", lookRight = "Look Right"
    case clap = "Clap", shrug = "Shrug", wave = "Wave"
    case dance = "Dance", think = "Think", surprised = "Surprised", speak = "Speak"
    case globe = "Globe", juggle = "Juggle"
    case butterfly = "Butterfly"
    case headphones = "Headphones"
    case sunglasses = "Sunglasses"
    case banana = "Banana", bananaMiss = "Banana Miss"

    var duration: Double {
        if let definition=RoutineLibrary.definitions[self] {return definition.duration}
        switch self {
        case .idle, .speak: return .infinity
        case .lookLeft, .lookRight: return LookAnimation.duration
        case .clap: return ClapAnimation.duration
        case .shrug: return ShrugAnimation.duration
        case .dance: return 8
        case .globe, .juggle, .banana, .bananaMiss, .sunglasses, .headphones, .butterfly: preconditionFailure("Missing routine definition")
        case .wave, .think, .surprised: return 4
        }
    }
    var changesFacing: Bool { RoutineLibrary.definitions[self]?.changesFacing ?? false }
}
