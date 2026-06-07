import Foundation

struct ProgramActivationPlan: Equatable {
    enum RuntimeSelection: Equatable {
        case queued(UUID)
        case detached(ProgramItem)
    }

    enum SideEffect: Equatable {
        case none
        case presentKeynote(URL)
        case openPPTX(URL)
        case openHTML(URL)
        case presentActiveDeck
        case invalidDeck(URL)
    }

    var item: ProgramItem
    var runtimeSelection: RuntimeSelection
    var shouldStopCurrentDeckPresentation: Bool
    var shouldClearHTML: Bool
    var sideEffect: SideEffect
}
