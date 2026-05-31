import Foundation

enum ConsoleModeSwitchProfiler {
    static let warningThreshold: TimeInterval = 0.5
    static let supportEventThreshold: TimeInterval = 1.0

    struct Start: Equatable {
        let targetMode: ConsoleMode
        let startedAt: Date
    }

    struct Event: Equatable {
        let targetMode: ConsoleMode
        let duration: TimeInterval

        var durationMilliseconds: Int {
            Int((duration * 1_000).rounded())
        }

        var shouldLogWarning: Bool {
            duration >= ConsoleModeSwitchProfiler.warningThreshold
        }

        var shouldRecordSupportEvent: Bool {
            duration >= ConsoleModeSwitchProfiler.supportEventThreshold
        }

        var supportEventDetail: String? {
            guard shouldRecordSupportEvent else { return nil }
            return "targetMode=\(targetMode.rawValue),durationMs=\(durationMilliseconds)"
        }
    }

    static func begin(targetMode: ConsoleMode, now: Date = Date()) -> Start {
        Start(targetMode: targetMode, startedAt: now)
    }

    static func end(_ start: Start, now: Date = Date()) -> Event {
        Event(targetMode: start.targetMode, duration: max(0, now.timeIntervalSince(start.startedAt)))
    }

    static func log(_ event: Event) {
        guard event.shouldLogWarning else { return }
        #if DEBUG
        print("LiveSwitcher console mode switch slow: targetMode=\(event.targetMode.rawValue),durationMs=\(event.durationMilliseconds)")
        #endif
    }
}
