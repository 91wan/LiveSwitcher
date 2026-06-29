import Foundation

struct RemoteControlSession: Equatable {
    var token: RemoteControlToken
    var createdAt: Date
}

struct RemoteDangerConfirmationChallenge: Equatable {
    var nonce: String
    var issuedAt: Date
    var expiresAt: Date
}

struct RemoteControlSessionStore {
    private(set) var activeSession: RemoteControlSession?
    private(set) var acceptedCommandIDs: Set<UUID> = []
    private(set) var dangerConfirmationExpirations: [String: Date] = [:]

    var isEnabled: Bool {
        activeSession != nil
    }

    mutating func enable(token: RemoteControlToken, now: Date) {
        activeSession = RemoteControlSession(token: token, createdAt: now)
        acceptedCommandIDs.removeAll()
        dangerConfirmationExpirations.removeAll()
    }

    mutating func disable() {
        activeSession = nil
        acceptedCommandIDs.removeAll()
        dangerConfirmationExpirations.removeAll()
    }

    mutating func markCommandIDIfNew(_ id: UUID) -> Bool {
        guard isEnabled else {
            return false
        }

        return acceptedCommandIDs.insert(id).inserted
    }

    mutating func issueDangerConfirmation(
        nonce: String,
        now: Date,
        ttl: TimeInterval
    ) -> RemoteDangerConfirmationChallenge {
        let expiresAt = now.addingTimeInterval(ttl)
        dangerConfirmationExpirations[nonce] = expiresAt
        return RemoteDangerConfirmationChallenge(
            nonce: nonce,
            issuedAt: now,
            expiresAt: expiresAt
        )
    }

    func dangerConfirmationExpiration(for nonce: String) -> Date? {
        dangerConfirmationExpirations[nonce]
    }
}
