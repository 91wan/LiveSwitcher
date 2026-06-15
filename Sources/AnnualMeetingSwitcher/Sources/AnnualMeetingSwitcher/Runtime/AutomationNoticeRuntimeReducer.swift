import Foundation

enum AutomationNoticeRuntimeReducer {
    static let suppressionDuration: TimeInterval = 15

    static func request(
        action: String,
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect],
        now: Date
    ) {
        state.automation.suppressionUntilByAction = state.automation.suppressionUntilByAction.filter { _, expiry in
            expiry > now
        }
        let notice = AutomationRuntimeNoticePolicy.make(action: action, createdAt: now)
        let suppressionUntil = state.automation.suppressionUntilByAction[action] ?? .distantPast
        guard suppressionUntil <= now else { return }

        state.automation.notice = notice
        state.automation.suppressionUntilByAction[action] = now.addingTimeInterval(suppressionDuration)
        effects.append(.showAutomationNotice(notice))
        if let expiresAt = notice.expiresAt {
            effects.append(.expireAutomationNotice(notice.id, at: expiresAt))
        }
    }

    static func expire(id: UUID, state: inout LiveRuntimeState) {
        if state.automation.notice?.id == id {
            state.automation.notice = nil
        }
    }

    static func dismiss(state: inout LiveRuntimeState) {
        state.automation.notice = nil
    }
}
