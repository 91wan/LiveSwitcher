import Foundation

struct ProgramActivationSideEffectHandlers {
    var presentKeynote: (URL) -> Void = { _ in }
    var openPPTX: (URL) -> Void = { _ in }
    var stopDeck: () -> Void = {}
    var presentActiveDeck: () -> Void = {}
    var presentInvalidDeckAlert: (URL) -> Void = { _ in }
}
