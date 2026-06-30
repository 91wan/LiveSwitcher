import Foundation

struct RemoteControlCommand: Codable, Equatable {
    var id: UUID
    var kind: RemoteControlCommandKind
    var confirmation: RemoteDangerConfirmation?

    init(
        id: UUID,
        kind: RemoteControlCommandKind,
        confirmation: RemoteDangerConfirmation? = nil
    ) {
        self.id = id
        self.kind = kind
        self.confirmation = confirmation
    }
}

enum RemoteControlCommandKind: String, Codable, CaseIterable {
    case takeNext
    case toggleCurrentMediaPlayback
    case returnCurrentMediaToStart
    case toggleBGMPlayback
    case selectPreviousBGM
    case selectNextBGM
    case toggleSpeakerMode
    case toggleFadeToBlack
    case togglePanic

    var liveModeAction: LiveModeActionKind {
        switch self {
        case .takeNext:
            return .takeNext
        case .toggleCurrentMediaPlayback:
            return .toggleCurrentMediaPlayback
        case .returnCurrentMediaToStart:
            return .returnCurrentMediaToStart
        case .toggleBGMPlayback:
            return .bgmPlayPause
        case .selectPreviousBGM:
            return .bgmPrevious
        case .selectNextBGM:
            return .bgmNext
        case .toggleSpeakerMode:
            return .toggleSpeakerMode
        case .toggleFadeToBlack:
            return .toggleFadeToBlack
        case .togglePanic:
            return .togglePanic
        }
    }

    var isDangerous: Bool {
        switch self {
        case .toggleFadeToBlack, .togglePanic:
            return true
        case .takeNext,
             .toggleCurrentMediaPlayback,
             .returnCurrentMediaToStart,
             .toggleBGMPlayback,
             .selectPreviousBGM,
             .selectNextBGM,
             .toggleSpeakerMode:
            return false
        }
    }
}

struct RemoteDangerConfirmation: Codable, Equatable {
    var nonce: String
}

struct RemoteControlAcceptedCommand: Equatable {
    var id: UUID
    var kind: RemoteControlCommandKind
    var liveModeAction: LiveModeActionKind
    var isDangerous: Bool
    var dangerConfirmationNonce: String? = nil
}

struct RemoteControlCommandValidationContext: Equatable {
    var isRemoteEnabled: Bool
    var acceptedCommandIDs: Set<UUID>
    var dangerConfirmationChallenges: [String: RemoteDangerConfirmationChallenge]
    var now: Date
}

enum RemoteControlCommandKindResolution: Equatable {
    case allowed(RemoteControlCommandKind)
    case rejected(RemoteControlCommandRejection)
}

enum RemoteControlCommandValidationResult: Equatable {
    case accepted(RemoteControlAcceptedCommand)
    case rejected(RemoteControlCommandRejection)
}

enum RemoteControlCommandRejection: Equatable {
    case remoteDisabled
    case duplicateCommandID
    case missingDangerConfirmation
    case unknownDangerConfirmation
    case expiredDangerConfirmation
    case consumedDangerConfirmation
    case mismatchedDangerConfirmationKind
    case insufficientDangerHoldDuration
    case dangerConfirmationNotRequired
    case forbiddenConfigurationCommand
    case commandNotInRemoteMVP
    case unknownCommand
}

enum RemoteControlCommandPolicy {
    static let minimumDangerHoldDuration: TimeInterval = 1.0

    static func resolveKind(_ rawValue: String) -> RemoteControlCommandKindResolution {
        if let kind = RemoteControlCommandKind(rawValue: rawValue) {
            return .allowed(kind)
        }

        if LiveModeConfigurationSurface(rawValue: rawValue) != nil {
            return .rejected(.forbiddenConfigurationCommand)
        }

        if LiveModeActionKind(rawValue: rawValue) != nil {
            return .rejected(.commandNotInRemoteMVP)
        }

        return .rejected(.unknownCommand)
    }

    static func validate(
        _ command: RemoteControlCommand,
        context: RemoteControlCommandValidationContext
    ) -> RemoteControlCommandValidationResult {
        guard context.isRemoteEnabled else {
            return .rejected(.remoteDisabled)
        }

        guard !context.acceptedCommandIDs.contains(command.id) else {
            return .rejected(.duplicateCommandID)
        }

        if command.kind.isDangerous {
            guard let confirmation = command.confirmation else {
                return .rejected(.missingDangerConfirmation)
            }

            guard let challenge = context.dangerConfirmationChallenges[confirmation.nonce] else {
                return .rejected(.unknownDangerConfirmation)
            }

            guard challenge.consumedAt == nil else {
                return .rejected(.consumedDangerConfirmation)
            }

            guard challenge.commandKind == command.kind else {
                return .rejected(.mismatchedDangerConfirmationKind)
            }

            guard context.now <= challenge.expiresAt else {
                return .rejected(.expiredDangerConfirmation)
            }

            guard context.now.timeIntervalSince(challenge.issuedAt) >= minimumDangerHoldDuration else {
                return .rejected(.insufficientDangerHoldDuration)
            }
        }

        return .accepted(RemoteControlAcceptedCommand(
            id: command.id,
            kind: command.kind,
            liveModeAction: command.kind.liveModeAction,
            isDangerous: command.kind.isDangerous,
            dangerConfirmationNonce: command.confirmation?.nonce
        ))
    }
}
