import Foundation

struct LiveStatusBarModel: Equatable {
    struct Item: Equatable {
        let title: String
        let value: String
        let status: StudioTheme.StatusKind
    }

    let projection: Item
    let current: Item
    let next: Item
    let audio: Item
    let panic: Item
    let speaker: Item
    let ppt: Item
    let isCritical: Bool

    static func make(snapshot: LivePreflightSnapshot, nextProgramTitle: String?) -> LiveStatusBarModel {
        let projection: Item
        if snapshot.isBroadcasting && !snapshot.hasExternalDisplay {
            projection = Item(title: "Projection", value: "ON AIR / DISPLAY LOST", status: .fail)
        } else if snapshot.isBroadcasting {
            projection = Item(title: "Projection", value: "ON AIR", status: .live)
        } else if snapshot.hasExternalDisplay {
            projection = Item(title: "Projection", value: "Standby", status: .idle)
        } else {
            projection = Item(title: "Projection", value: "No External Display", status: .warn)
        }

        let currentTitle = snapshot.currentProgramTitle?.isEmpty == false
            ? snapshot.currentProgramTitle!
            : "No Program"
        let currentValue = snapshot.currentProgramSource.map { "\(currentTitle) · \($0)" } ?? currentTitle

        return LiveStatusBarModel(
            projection: projection,
            current: Item(
                title: "Current",
                value: currentValue,
                status: snapshot.currentProgramTitle == nil ? .warn : (snapshot.isBroadcasting ? .live : .idle)
            ),
            next: Item(
                title: "Next",
                value: nextProgramTitle?.isEmpty == false ? nextProgramTitle! : "None",
                status: nextProgramTitle == nil ? .idle : .ready
            ),
            audio: Item(
                title: "Audio",
                value: "Media \(formatPercent(snapshot.effectiveMediaVolume)) / BGM \(formatPercent(snapshot.effectiveBGMVolume))",
                status: snapshot.isPanicMode ? .muted : .ready
            ),
            panic: Item(
                title: "Panic",
                value: snapshot.isPanicMode ? "Active" : "Off",
                status: snapshot.isPanicMode ? .fail : .ready
            ),
            speaker: Item(
                title: "Speaker",
                value: snapshot.isSpeakerMode ? "On" : "Off",
                status: snapshot.isSpeakerMode ? .warn : .idle
            ),
            ppt: Item(
                title: "PPT",
                value: snapshot.isPageInterceptEnabled ? "On" : "Off",
                status: snapshot.isPageInterceptEnabled ? .warn : .idle
            ),
            isCritical: snapshot.isPanicMode || snapshot.isBroadcasting
        )
    }

    private static func formatPercent(_ volume: Float) -> String {
        "\(Int((max(0, min(volume, 1)) * 100).rounded()))%"
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
            return PreflightButtonModel(title: "Preflight", value: "Review", status: .warn)
        case .fail:
            return PreflightButtonModel(title: "Preflight", value: "Fail", status: .fail)
        }
    }
}
