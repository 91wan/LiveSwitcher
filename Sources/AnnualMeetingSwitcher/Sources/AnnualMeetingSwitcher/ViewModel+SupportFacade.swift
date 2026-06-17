import Foundation

@MainActor
extension SwitcherViewModel {
    func recordSupportEvent(
        kind: LiveSupportEventKind,
        detail: String,
        timestamp: Date = Date()
    ) {
        let event = LiveSupportEvent(timestamp: timestamp, kind: kind, detail: detail)
        dispatchRuntimeFacadeAction(.supportEventRecorded(event))
    }
}
