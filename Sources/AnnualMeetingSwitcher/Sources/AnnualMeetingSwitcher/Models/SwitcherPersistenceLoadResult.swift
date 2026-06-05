import Foundation

struct SwitcherPersistenceLoadResult {
    var state: SwitcherPersistentState
    var supportEvents: [LiveSupportEvent]
    var repairs: [SwitcherPersistenceRepair]

    init(
        state: SwitcherPersistentState = SwitcherPersistentState(),
        supportEvents: [LiveSupportEvent] = [],
        repairs: [SwitcherPersistenceRepair] = []
    ) {
        self.state = state
        self.supportEvents = supportEvents
        self.repairs = repairs
    }
}
