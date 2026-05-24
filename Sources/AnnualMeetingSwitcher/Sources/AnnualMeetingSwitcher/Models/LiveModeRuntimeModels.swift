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
            return LiveCutBusModel(canTakeNext: false, nextIndex: nil, nextTitle: "No next source")
        }

        let nextIndex: Int?
        if let currentID = currentProgramItem?.id,
           let currentIndex = programItems.firstIndex(where: { $0.id == currentID }) {
            let candidate = programItems.index(after: currentIndex)
            nextIndex = candidate < programItems.endIndex ? candidate : nil
        } else {
            nextIndex = programItems.startIndex
        }

        guard let nextIndex else {
            return LiveCutBusModel(canTakeNext: false, nextIndex: nil, nextTitle: "No next source")
        }

        return LiveCutBusModel(
            canTakeNext: true,
            nextIndex: nextIndex,
            nextTitle: programItems[nextIndex].title
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
        let failChips = checks
            .filter { $0.status == .fail }
            .prefix(3)
            .map { LiveRuntimeStatusChip(text: "FAIL · \($0.title)", kind: .fail) }
        let warnChips = checks
            .filter { $0.status == .warn }
            .prefix(3)
            .map { LiveRuntimeStatusChip(text: "WARN · \($0.title)", kind: .warn) }

        let output = snapshot.isBroadcasting ? "ON AIR" : "STANDBY"
        let current = snapshot.currentProgramTitle ?? "No program"
        let summary = LiveRuntimeStatusChip(
            text: "\(output) · Current: \(current) · \(snapshot.programItemCount) sources",
            kind: snapshot.isBroadcasting ? .live : .ready
        )

        return LiveRuntimeStatusModel(
            chips: Array(failChips) + Array(warnChips) + [summary]
        )
    }
}
