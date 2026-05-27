import Foundation

struct LiveAudioMeterModel: Equatable {
    let level: Double
    let decibelText: String
    let statusKind: StudioTheme.StatusKind
    let isEstimated: Bool

    static func make(effectiveVolume: Float, isMuted: Bool) -> LiveAudioMeterModel {
        make(realtimeDB: nil, fallbackEffectiveVolume: effectiveVolume, isMuted: isMuted)
    }

    static func make(realtimeDB: Float?, fallbackEffectiveVolume: Float, isMuted: Bool) -> LiveAudioMeterModel {
        guard !isMuted else {
            return LiveAudioMeterModel(level: 0, decibelText: "-∞ dB", statusKind: .muted, isEstimated: false)
        }

        if let realtimeDB, realtimeDB.isFinite {
            let outputGain = min(max(Double(fallbackEffectiveVolume), 0), 1)
            guard outputGain > 0 else {
                return LiveAudioMeterModel(level: 0, decibelText: "-∞ dB", statusKind: .muted, isEstimated: false)
            }

            let gainDB = 20 * log10(outputGain)
            let clampedDB = min(max(Double(realtimeDB) + gainDB, -60), 0)
            let roundedDB = Int(clampedDB.rounded())
            let level = max(0, min((clampedDB + 60) / 60, 1))
            let status: StudioTheme.StatusKind = roundedDB >= -3 ? .warn : .ready
            return LiveAudioMeterModel(
                level: level,
                decibelText: roundedDB <= -60 ? "-∞ dB" : "\(roundedDB) dB",
                statusKind: status,
                isEstimated: false
            )
        }

        let clamped = min(max(Double(fallbackEffectiveVolume), 0), 1)
        guard clamped > 0 else {
            return LiveAudioMeterModel(level: 0, decibelText: "-∞ dB", statusKind: .muted, isEstimated: true)
        }

        let decibels = 20 * log10(clamped)
        let roundedDB = Int(decibels.rounded())
        let status: StudioTheme.StatusKind = roundedDB >= -3 ? .warn : .ready
        return LiveAudioMeterModel(
            level: clamped,
            decibelText: "≈ \(roundedDB) dB",
            statusKind: status,
            isEstimated: true
        )
    }
}

struct LiveCutBusModel: Equatable {
    let canTakeNext: Bool
    let nextIndex: Int?
    let nextTitle: String

    static func make(programItems: [ProgramItem], currentProgramItem: ProgramItem?) -> LiveCutBusModel {
        guard !programItems.isEmpty else {
            return LiveCutBusModel(canTakeNext: false, nextIndex: nil, nextTitle: "没有下一项")
        }

        let nextIndex = ProgramQueueStore.nextPlayableIndexAfterCurrent(
            current: currentProgramItem,
            in: programItems
        )

        guard let nextIndex else {
            return LiveCutBusModel(canTakeNext: false, nextIndex: nil, nextTitle: "没有下一项")
        }

        return LiveCutBusModel(
            canTakeNext: true,
            nextIndex: nextIndex,
            nextTitle: programItems[nextIndex].title
        )
    }
}

struct LiveMediaRestartControlModel: Equatable {
    let isEnabled: Bool
    let title: String
    let help: String?

    static func make(currentItem: ProgramItem?) -> LiveMediaRestartControlModel {
        guard let currentItem, currentItem.supportsSeeking else {
            return LiveMediaRestartControlModel(
                isEnabled: false,
                title: "从头播放",
                help: nil
            )
        }

        return LiveMediaRestartControlModel(
            isEnabled: true,
            title: "从头播放",
            help: "从头重新播放当前视频"
        )
    }
}

struct LiveRuntimeStatusChip: Equatable {
    let text: String
    let kind: StudioTheme.StatusKind
}

struct LiveRuntimeStatusModel: Equatable {
    let chips: [LiveRuntimeStatusChip]

    var text: String {
        chips.map(\.text).joined(separator: " │ ")
    }

    var kind: StudioTheme.StatusKind {
        chips.first?.kind ?? .idle
    }

    static func make(snapshot: LivePreflightSnapshot) -> LiveRuntimeStatusModel {
        let checks = LivePreflightCheck.build(from: snapshot)
        return make(checks: checks, snapshot: snapshot)
    }

    static func make(checks: [LivePreflightCheck], snapshot: LivePreflightSnapshot) -> LiveRuntimeStatusModel {
        let failChips = checks
            .filter { $0.status == .fail }
            .map { LiveRuntimeStatusChip(text: "故障 · \($0.title)", kind: .fail) }
        let warnChips = checks
            .filter { $0.status == .warn }
            .map { LiveRuntimeStatusChip(text: "警告 · \($0.title)", kind: .warn) }
        let visibleFailChips = Array(failChips.prefix(2))
        let visibleWarnChips = Array(warnChips.prefix(1))
        let hiddenFailCount = failChips.count - visibleFailChips.count
        let hiddenWarnCount = warnChips.count - visibleWarnChips.count
        let overflowCount = hiddenFailCount + hiddenWarnCount

        let output = snapshot.isBroadcasting ? "直播" : "待机"
        let current = snapshot.currentProgramTitle ?? "无节目"
        let summary = LiveRuntimeStatusChip(
            text: "\(output) · 当前: \(current) · \(snapshot.programItemCount) 个信号源",
            kind: snapshot.isBroadcasting ? .live : .ready
        )

        let overflowChip: [LiveRuntimeStatusChip]
        if overflowCount > 0 {
            overflowChip = [
                LiveRuntimeStatusChip(
                    text: overflowText(hiddenFailCount: hiddenFailCount, hiddenWarnCount: hiddenWarnCount),
                    kind: hiddenFailCount > 0 ? .fail : .warn
                )
            ]
        } else {
            overflowChip = []
        }

        let scheduleChip: [LiveRuntimeStatusChip]
        if let currentProgramTitle = snapshot.currentProgramTitle {
            let scheduleStatus = AgendaScheduleStatusModel.make(
                currentItem: ProgramItem(
                    title: currentProgramTitle,
                    scheduledStartAt: snapshot.currentProgramScheduledStartAt,
                    scheduledDuration: snapshot.currentProgramScheduledDuration
                ),
                switchedAt: snapshot.currentProgramSwitchedAt,
                now: snapshot.scheduleNow
            )
            scheduleChip = scheduleStatus.state == .none
                ? []
                : [LiveRuntimeStatusChip(text: scheduleStatus.text, kind: scheduleStatus.kind)]
        } else {
            scheduleChip = []
        }

        return LiveRuntimeStatusModel(
            chips: visibleFailChips + visibleWarnChips + overflowChip + scheduleChip + [summary]
        )
    }

    private static func overflowText(hiddenFailCount: Int, hiddenWarnCount: Int) -> String {
        if hiddenFailCount > 0 {
            if hiddenWarnCount > 0 {
                return "+ \(hiddenFailCount) 故障 · \(hiddenWarnCount) 警告"
            }
            return "+ \(hiddenFailCount) 故障"
        }
        return "+ \(hiddenWarnCount) 个警告"
    }
}
