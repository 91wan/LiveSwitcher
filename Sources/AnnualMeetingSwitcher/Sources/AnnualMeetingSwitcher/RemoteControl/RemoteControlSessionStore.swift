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

struct RemoteDangerConfirmationChallenge: Equatable {
    var nonce: String
    var commandKind: RemoteControlCommandKind
    var issuedAt: Date
    var expiresAt: Date
    var consumedAt: Date?
}

struct RemoteControlSessionStore {
    private(set) var activeSession: RemoteControlSession?
    private(set) var acceptedCommandIDs: Set<UUID> = []
    private(set) var dangerConfirmationChallenges: [String: RemoteDangerConfirmationChallenge] = [:]

    var isEnabled: Bool {
        activeSession != nil
    }

    mutating func enable(token: RemoteControlToken, now: Date) {
        activeSession = RemoteControlSession(token: token, createdAt: now)
        acceptedCommandIDs.removeAll()
        dangerConfirmationChallenges.removeAll()
    }

    mutating func disable() {
        activeSession = nil
        acceptedCommandIDs.removeAll()
        dangerConfirmationChallenges.removeAll()
    }

    mutating func markCommandIDIfNew(_ id: UUID) -> Bool {
        guard isEnabled else {
            return false
        }

        return acceptedCommandIDs.insert(id).inserted
    }

    mutating func issueDangerConfirmation(
        nonce: String,
        commandKind: RemoteControlCommandKind,
        now: Date,
        ttl: TimeInterval
    ) -> RemoteDangerConfirmationChallenge {
        let expiresAt = now.addingTimeInterval(ttl)
        let challenge = RemoteDangerConfirmationChallenge(
            nonce: nonce,
            commandKind: commandKind,
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
