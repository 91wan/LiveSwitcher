import Foundation

struct RemoteControlSession: Equatable {
    var token: RemoteControlToken
    var createdAt: Date
}

struct RemoteControlSessionCloseResult: Equatable {
    var closed: Bool

    static let closed = RemoteControlSessionCloseResult(closed: true)
    static let remoteDisabled = RemoteControlSessionCloseResult(closed: false)
}

struct RemoteControlClientID: Codable, Equatable, Hashable {
    var value: String
}

enum RemoteControlClientIDPolicy {
    private static let lengthRange = 8...80
    private static let allowedCharacters = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-")

    static func normalized(_ value: String?) -> RemoteControlClientID? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              lengthRange.contains(trimmed.count) else {
            return nil
        }

        guard trimmed.unicodeScalars.allSatisfy({ allowedCharacters.contains($0) }) else {
            return nil
        }

        return RemoteControlClientID(value: trimmed)
    }
}

enum RemoteControlClientRole: String, Codable {
    case controller
    case readOnly
}

enum RemoteControlSessionClaimResult: Equatable {
    case controller
    case readOnly
    case remoteDisabled
}

struct RemoteDangerConfirmationChallenge: Equatable {
    var nonce: String
    var commandKind: RemoteControlCommandKind
    var clientID: RemoteControlClientID? = nil
    var issuedAt: Date
    var expiresAt: Date
    var consumedAt: Date?
}

enum RemoteControlCommandReplayPolicy {
    static let maxAcceptedCommandIDs = 4_096
}

struct RemoteControlSessionStore {
    private(set) var activeSession: RemoteControlSession?
    private(set) var controllerClientID: RemoteControlClientID?
    private(set) var acceptedCommandIDs: Set<UUID> = []
    private(set) var dangerConfirmationChallenges: [String: RemoteDangerConfirmationChallenge] = [:]
    private var acceptedCommandIDOrder: [UUID] = []
    private var nextAcceptedCommandIDEvictionIndex = 0

    var isEnabled: Bool {
        activeSession != nil
    }

    mutating func enable(token: RemoteControlToken, now: Date) {
        activeSession = RemoteControlSession(token: token, createdAt: now)
        controllerClientID = nil
        resetAcceptedCommandIDHistory()
        dangerConfirmationChallenges.removeAll()
    }

    mutating func disable() {
        activeSession = nil
        controllerClientID = nil
        resetAcceptedCommandIDHistory()
        dangerConfirmationChallenges.removeAll()
    }

    mutating func claimController(clientID: RemoteControlClientID) -> RemoteControlSessionClaimResult {
        guard isEnabled else {
            return .remoteDisabled
        }

        guard let currentController = controllerClientID else {
            controllerClientID = clientID
            return .controller
        }

        return currentController == clientID ? .controller : .readOnly
    }

    func canExecuteCommand(from clientID: RemoteControlClientID) -> Bool {
        isEnabled && controllerClientID == clientID
    }

    mutating func markCommandIDIfNew(_ id: UUID) -> Bool {
        guard isEnabled else {
            return false
        }

        guard !acceptedCommandIDs.contains(id) else {
            return false
        }

        if acceptedCommandIDOrder.count < RemoteControlCommandReplayPolicy.maxAcceptedCommandIDs {
            acceptedCommandIDOrder.append(id)
        } else {
            let evictedID = acceptedCommandIDOrder[nextAcceptedCommandIDEvictionIndex]
            acceptedCommandIDs.remove(evictedID)
            acceptedCommandIDOrder[nextAcceptedCommandIDEvictionIndex] = id
            nextAcceptedCommandIDEvictionIndex = (
                nextAcceptedCommandIDEvictionIndex + 1
            ) % RemoteControlCommandReplayPolicy.maxAcceptedCommandIDs
        }
        acceptedCommandIDs.insert(id)
        return true
    }

    private mutating func resetAcceptedCommandIDHistory() {
        acceptedCommandIDs.removeAll()
        acceptedCommandIDOrder.removeAll()
        nextAcceptedCommandIDEvictionIndex = 0
    }

    mutating func issueDangerConfirmation(
        nonce: String,
        commandKind: RemoteControlCommandKind,
        clientID: RemoteControlClientID?,
        now: Date,
        ttl: TimeInterval
    ) -> RemoteDangerConfirmationChallenge {
        let expiresAt = now.addingTimeInterval(ttl)
        let challenge = RemoteDangerConfirmationChallenge(
            nonce: nonce,
            commandKind: commandKind,
            clientID: clientID,
            issuedAt: now,
            expiresAt: expiresAt,
            consumedAt: nil
        )
        dangerConfirmationChallenges[nonce] = challenge
        return challenge
    }

    func dangerConfirmationExpiration(for nonce: String) -> Date? {
        dangerConfirmationChallenges[nonce]?.expiresAt
    }

    func dangerConfirmation(for nonce: String) -> RemoteDangerConfirmationChallenge? {
        dangerConfirmationChallenges[nonce]
    }

    @discardableResult
    mutating func consumeDangerConfirmation(nonce: String, now: Date) -> Bool {
        guard var challenge = dangerConfirmationChallenges[nonce],
              challenge.consumedAt == nil else {
            return false
        }

        challenge.consumedAt = now
        dangerConfirmationChallenges[nonce] = challenge
        return true
    }
}
