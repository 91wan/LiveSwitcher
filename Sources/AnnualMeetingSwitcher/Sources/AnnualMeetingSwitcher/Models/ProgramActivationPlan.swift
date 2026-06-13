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

extension ProgramActivationPlan {
    var redactedForRecording: ProgramActivationPlan {
        ProgramActivationPlan(
            item: item.redactedForActivationRecording,
            runtimeSelection: runtimeSelection?.redactedForRecording,
            preSelectionEffects: preSelectionEffects.map(\.redactedForRecording),
            postSelectionEffects: postSelectionEffects.map(\.redactedForRecording)
        )
    }
}

private extension ProgramActivationPlan.RuntimeSelection {
    var redactedForRecording: ProgramActivationPlan.RuntimeSelection {
        switch self {
        case .queued(let id):
            return .queued(id)
        case .detached(let item):
            return .detached(item.redactedForActivationRecording)
        }
    }
}

private extension ProgramActivationPlan.PreSelectionEffect {
    var redactedForRecording: ProgramActivationPlan.PreSelectionEffect {
        switch self {
        case .stopDeck:
            return .stopDeck
        case .presentInvalidDeckAlert:
            return .presentInvalidDeckAlert(ProgramItem.redactedActivationURL)
        }
    }
}

private extension ProgramActivationPlan.PostSelectionEffect {
    var redactedForRecording: ProgramActivationPlan.PostSelectionEffect {
        switch self {
        case .clearHTML:
            return .clearHTML
        case .resetMutedMediaStartupFlag:
            return .resetMutedMediaStartupFlag
        case .presentKeynote:
            return .presentKeynote(ProgramItem.redactedActivationURL)
        case .openPPTX:
            return .openPPTX(ProgramItem.redactedActivationURL)
        case .openHTML:
            return .openHTML(ProgramItem.redactedActivationURL)
        case .presentActiveDeck:
            return .presentActiveDeck
        }
    }
}

private extension ProgramItem {
    static let redactedActivationURL = URL(fileURLWithPath: "/redacted")

    var redactedForActivationRecording: ProgramItem {
        ProgramItem(
            id: id,
            title: "<redacted>",
            subtitle: "<redacted>",
            sourceURL: nil,
            scheduledStartAt: scheduledStartAt,
            scheduledDuration: scheduledDuration
        )
    }
}
