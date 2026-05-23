import Foundation

struct LiveStatusBarModel: Equatable {
    struct Item: Equatable {
        enum LayoutRole: Equatable {
            case compact
            case primary
            case flexible

            var maxWidth: Double {
                switch self {
                case .compact:
                    return 170
                case .primary:
                    return 260
                case .flexible:
                    return 220
                }
            }
        }

        let title: String
        let value: String
        let accessibilityValue: String
        let status: StudioTheme.StatusKind
        let layoutRole: LayoutRole

        init(
            title: String,
            value: String,
            status: StudioTheme.StatusKind,
            accessibilityValue: String? = nil,
            layoutRole: LayoutRole = .compact
        ) {
            self.title = title
            self.value = value
            self.accessibilityValue = accessibilityValue ?? value
            self.status = status
            self.layoutRole = layoutRole
        }
    }

    let projection: Item
    let current: Item
    let next: Item
    let audio: Item
    let isCritical: Bool

    var items: [Item] {
        [projection, current, next, audio]
    }

    static func make(snapshot: LivePreflightSnapshot, nextProgramTitle: String?) -> LiveStatusBarModel {
        let projection: Item
        if snapshot.isBroadcasting && !snapshot.hasExternalDisplay {
            projection = Item(title: "Output", value: "Display Lost", status: .fail)
        } else if snapshot.isBroadcasting {
            projection = Item(title: "Output", value: "ON AIR", status: .live)
        } else if snapshot.hasExternalDisplay {
            projection = Item(title: "Output", value: "Standby", status: .idle)
        } else {
            projection = Item(title: "Output", value: "No Display", status: .warn)
        }

        let currentTitle = snapshot.currentProgramTitle?.isEmpty == false
            ? snapshot.currentProgramTitle!
            : "No Program"
        let currentValue = snapshot.currentProgramSource.map { "\(currentTitle) · \($0)" } ?? currentTitle
        let nextValue = nextProgramTitle?.isEmpty == false ? nextProgramTitle! : "None"
        let audio = audioItem(snapshot: snapshot)

        return LiveStatusBarModel(
            projection: projection,
            current: Item(
                title: "Current",
                value: truncatedDisplay(currentValue),
                status: snapshot.currentProgramTitle == nil ? .warn : (snapshot.isBroadcasting ? .live : .idle),
                accessibilityValue: currentValue,
                layoutRole: .primary
            ),
            next: Item(
                title: "Next",
                value: truncatedDisplay(nextValue),
                status: nextProgramTitle == nil ? .idle : .ready,
                accessibilityValue: nextValue,
                layoutRole: .flexible
            ),
            audio: audio,
            isCritical: snapshot.isPanicMode || snapshot.isBroadcasting
        )
    }

    private static func audioItem(snapshot: LivePreflightSnapshot) -> Item {
        if snapshot.isPanicMode {
            return Item(title: "Audio", value: "Muted by Panic", status: .fail)
        }
        if snapshot.isBGMAudioTakeoverActive {
            return Item(title: "Audio", value: "BGM Takeover", status: .warn)
        }
        if snapshot.isSpeakerMode {
            return Item(title: "Audio", value: "Speaker", status: .warn)
        }
        return Item(title: "Audio", value: "Normal", status: .ready)
    }

    private static func truncatedDisplay(_ value: String, maxLength: Int = 24) -> String {
        guard value.count > maxLength else { return value }
        let prefixCount = max(1, (maxLength - 1) / 2)
        let suffixCount = max(1, maxLength - prefixCount - 1)
        return "\(value.prefix(prefixCount))…\(value.suffix(suffixCount))"
    }
}

struct PreflightButtonModel: Equatable {
    let title: String
    let value: String
    let status: StudioTheme.StatusKind

    static func make(summary: LivePreflightSummary) -> PreflightButtonModel {
        switch summary.status {
        case .pass:
            return PreflightButtonModel(title: "Preflight", value: "Ready", status: .ready)
        case .warn:
            return PreflightButtonModel(title: "Preflight", value: countText(failCount: 0, warnCount: summary.warnCount), status: .warn)
        case .fail:
            return PreflightButtonModel(title: "Preflight", value: countText(failCount: summary.failCount, warnCount: summary.warnCount), status: .fail)
        }
    }

    private static func countText(failCount: Int, warnCount: Int) -> String {
        var parts: [String] = []
        if failCount > 0 {
            parts.append("\(failCount) Fail")
        }
        if warnCount > 0 {
            parts.append("\(warnCount) Warn")
        }
        return parts.isEmpty ? "Review" : parts.joined(separator: " · ")
    }
}
