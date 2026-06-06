import Foundation

struct SwitcherViewModelActionHandlers {
    var keynotePresentation: (URL) -> Void = { _ in }
    var pptxOpen: (URL) -> Void = { _ in }
    var deckStop: () -> Void = {}
    var programSeekToStart: () -> Void = {}
    var programRestartFromBeginning: (@escaping () -> Void) -> Void = { _ in }
    var programSeekToEnd: () -> Void = {}
    var activeDeckPresentation: () -> Void = {}
    var invalidDeck: (URL) -> Void = { _ in }
}
