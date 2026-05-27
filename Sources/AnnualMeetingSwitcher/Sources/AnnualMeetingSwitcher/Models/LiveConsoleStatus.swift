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
            projection = Item(title: "输出", value: "副屏丢失", status: .fail)
        } else if snapshot.isBroadcasting {
            projection = Item(title: "输出", value: "直播", status: .live)
        } else if snapshot.hasExternalDisplay {
            projection = Item(title: "输出", value: "待机", status: .idle)
        } else {
            projection = Item(title: "输出", value: "无副屏", status: .warn)
        }

        let currentTitle = snapshot.currentProgramTitle?.isEmpty == false
            ? snapshot.currentProgramTitle!
            : "无节目"
        let currentValue = snapshot.currentProgramSource.map { "\(currentTitle) · \($0)" } ?? currentTitle
        let nextValue = nextProgramTitle?.isEmpty == false ? nextProgramTitle! : "无"
        let audio = audioItem(snapshot: snapshot)

        return LiveStatusBarModel(
            projection: projection,
            current: Item(
                title: "当前",
                value: truncatedDisplay(currentValue),
                status: snapshot.currentProgramTitle == nil ? .idle : (snapshot.isBroadcasting ? .live : .idle),
                accessibilityValue: currentValue,
                layoutRole: .primary
            ),
            next: Item(
                title: "下一项",
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
            return Item(title: "音频", value: "紧急切黑静音", status: .fail)
        }
        if snapshot.isBGMAudioTakeoverActive {
            return Item(title: "音频", value: "BGM 接管", status: .warn)
        }
        if snapshot.isSpeakerMode {
            return Item(title: "音频", value: "主持人", status: .warn)
        }
        return Item(title: "音频", value: "正常", status: .ready)
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
            return PreflightButtonModel(title: "检查", value: "就绪", status: .ready)
        case .warn:
            return PreflightButtonModel(title: "检查", value: countText(failCount: 0, warnCount: summary.warnCount), status: .warn)
        case .fail:
            return PreflightButtonModel(title: "检查", value: countText(failCount: summary.failCount, warnCount: summary.warnCount), status: .fail)
        }
    }

    private static func countText(failCount: Int, warnCount: Int) -> String {
        var parts: [String] = []
        if failCount > 0 {
            parts.append("\(failCount) 故障")
        }
        if warnCount > 0 {
            parts.append("\(warnCount) 警告")
        }
        return parts.isEmpty ? "复核" : parts.joined(separator: " · ")
    }
}
