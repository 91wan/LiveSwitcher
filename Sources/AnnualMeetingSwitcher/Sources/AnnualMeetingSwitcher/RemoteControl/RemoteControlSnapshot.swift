import Foundation

enum RemoteConnectionState: String, Codable, Equatable {
    case disabled
    case enabled
    case connected
    case readOnly
}

struct RemoteControlSnapshot: Codable, Equatable {
    var connectionState: RemoteConnectionState
    var currentProgramTitle: String?
    var nextProgramTitle: String?
    var isBroadcasting: Bool
    var isPanicActive: Bool
    var isFadeToBlackActive: Bool
    var isCurrentMediaPlaying: Bool
    var canToggleCurrentMedia: Bool
    var canReturnCurrentMediaToStart: Bool
    var currentBGMTitle: String?
    var isBGMPlaying: Bool
    var canSelectPreviousBGM: Bool
    var canSelectNextBGM: Bool
    var isSpeakerMode: Bool
    var disabledReason: String?

    private enum CodingKeys: String, CodingKey {
        case connectionState
        case currentProgramTitle
        case nextProgramTitle
        case isBroadcasting
        case isPanicActive
        case isFadeToBlackActive
        case isCurrentMediaPlaying
        case canToggleCurrentMedia
        case canReturnCurrentMediaToStart
        case currentBGMTitle
        case isBGMPlaying
        case canSelectPreviousBGM
        case canSelectNextBGM
        case isSpeakerMode
        case disabledReason
    }

    init(
        connectionState: RemoteConnectionState,
        currentProgramTitle: String?,
        nextProgramTitle: String?,
        isBroadcasting: Bool,
        isPanicActive: Bool,
        isFadeToBlackActive: Bool,
        isCurrentMediaPlaying: Bool,
        canToggleCurrentMedia: Bool,
        canReturnCurrentMediaToStart: Bool,
        currentBGMTitle: String?,
        isBGMPlaying: Bool,
        canSelectPreviousBGM: Bool,
        canSelectNextBGM: Bool,
        isSpeakerMode: Bool,
        disabledReason: String?
    ) {
        self.connectionState = connectionState
        self.currentProgramTitle = Self.safeDisplayText(currentProgramTitle)
        self.nextProgramTitle = Self.safeDisplayText(nextProgramTitle)
        self.isBroadcasting = isBroadcasting
        self.isPanicActive = isPanicActive
        self.isFadeToBlackActive = isFadeToBlackActive
        self.isCurrentMediaPlaying = isCurrentMediaPlaying
        self.canToggleCurrentMedia = canToggleCurrentMedia
        self.canReturnCurrentMediaToStart = canReturnCurrentMediaToStart
        self.currentBGMTitle = Self.safeDisplayText(currentBGMTitle)
        self.isBGMPlaying = isBGMPlaying
        self.canSelectPreviousBGM = canSelectPreviousBGM
        self.canSelectNextBGM = canSelectNextBGM
        self.isSpeakerMode = isSpeakerMode
        self.disabledReason = Self.safeDisplayText(disabledReason)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            connectionState: try container.decode(RemoteConnectionState.self, forKey: .connectionState),
            currentProgramTitle: try container.decodeIfPresent(String.self, forKey: .currentProgramTitle),
            nextProgramTitle: try container.decodeIfPresent(String.self, forKey: .nextProgramTitle),
            isBroadcasting: try container.decode(Bool.self, forKey: .isBroadcasting),
            isPanicActive: try container.decode(Bool.self, forKey: .isPanicActive),
            isFadeToBlackActive: try container.decode(Bool.self, forKey: .isFadeToBlackActive),
            isCurrentMediaPlaying: try container.decode(Bool.self, forKey: .isCurrentMediaPlaying),
            canToggleCurrentMedia: try container.decode(Bool.self, forKey: .canToggleCurrentMedia),
            canReturnCurrentMediaToStart: try container.decode(Bool.self, forKey: .canReturnCurrentMediaToStart),
            currentBGMTitle: try container.decodeIfPresent(String.self, forKey: .currentBGMTitle),
            isBGMPlaying: try container.decode(Bool.self, forKey: .isBGMPlaying),
            canSelectPreviousBGM: try container.decode(Bool.self, forKey: .canSelectPreviousBGM),
            canSelectNextBGM: try container.decode(Bool.self, forKey: .canSelectNextBGM),
            isSpeakerMode: try container.decode(Bool.self, forKey: .isSpeakerMode),
            disabledReason: try container.decodeIfPresent(String.self, forKey: .disabledReason)
        )
    }

    var redactedDiagnosticsSummary: String {
        [
            "connection=\(connectionState.rawValue)",
            "broadcasting=\(isBroadcasting)",
            "panic=\(isPanicActive)",
            "fadeToBlack=\(isFadeToBlackActive)",
            "mediaPlaying=\(isCurrentMediaPlaying)",
            "bgmPlaying=\(isBGMPlaying)",
            "speakerMode=\(isSpeakerMode)",
            "disabledReason=\(disabledReason == nil ? "none" : "redacted")"
        ].joined(separator: ",")
    }

    private static func safeDisplayText(_ text: String?) -> String? {
        guard let text else {
            return nil
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        if looksLikeFilePath(trimmed) {
            return "[redacted]"
        }

        return trimmed
    }

    private static func looksLikeFilePath(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        return lowercased.hasPrefix("file://")
            || text.hasPrefix("/")
            || text.hasPrefix("~/")
            || text.contains("/Users/")
            || text.contains("/Volumes/")
            || text.contains("/private/")
            || text.contains("\\")
    }
}
