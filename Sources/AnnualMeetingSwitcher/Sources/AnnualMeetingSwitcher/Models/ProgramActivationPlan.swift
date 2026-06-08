import Foundation

struct ProgramActivationPlan: Equatable {
    enum RuntimeSelection: Equatable {
        case queued(UUID)
        case detached(ProgramItem)
    }

    enum PreSelectionEffect: Equatable {
        case stopDeck
        case presentInvalidDeckAlert(URL)
    }

    enum PostSelectionEffect: Equatable {
        case clearHTML
        case resetMutedMediaStartupFlag
        case presentKeynote(URL)
        case openPPTX(URL)
        case openHTML(URL)
        case presentActiveDeck
    }

    var item: ProgramItem
    var runtimeSelection: RuntimeSelection?
    var preSelectionEffects: [PreSelectionEffect]
    var postSelectionEffects: [PostSelectionEffect]

    var abortsBeforeSelection: Bool {
        for effect in preSelectionEffects {
            if case .presentInvalidDeckAlert = effect {
                return true
            }
        }
        return false
    }
}
