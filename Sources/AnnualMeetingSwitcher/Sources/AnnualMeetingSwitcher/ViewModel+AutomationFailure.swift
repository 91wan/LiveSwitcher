import AppKit

@MainActor
extension SwitcherViewModel {
    func handleAppleScriptFailure(_ error: Error, action: String) {
        let sanitizedMessage = sanitizedAutomationFailureMessage(error)
        let supportMessage = AutomationFailureSanitizer.sanitizedSupportMessage(from: error)
        recordSupportEvent(kind: .appleScriptFailed, detail: "action=\(action),error=\(supportMessage)")
        dispatchRuntimeFacadeAction(.automationFailed(action: action, sanitizedMessage: sanitizedMessage))
    }

    func dismissAutomationRuntimeNotice() {
        cancelAutomationNoticeExpiryTask()
        dispatchRuntimeFacadeAction(.automationNoticeDismissed)
    }

    func expireAutomationRuntimeNotice(id: UUID, now: Date = Date()) {
        guard let notice = automationRuntimeNotice,
              notice.id == id,
              let expiresAt = notice.expiresAt,
              now >= expiresAt
        else { return }
        cancelAutomationNoticeExpiryTask()
        dispatchRuntimeFacadeAction(.automationNoticeExpired(id))
    }

    func showAutomationRuntimeNotice(action: String) {
        dispatchRuntimeFacadeAction(.automationNoticeRequested(action: action))
    }

    func cancelAutomationNoticeExpiryTask() {
        cleanupBag.automationNoticeExpiryTask?.cancel()
        cleanupBag.automationNoticeExpiryTask = nil
        cleanupBag.automationNoticeExpiryTaskNoticeID = nil
    }

    func expireAutomationNoticeFromScheduledTask(id: UUID) {
        guard runtime.state.automation.notice?.id == id else { return }
        dispatchRuntimeFacadeAction(.automationNoticeExpired(id))
    }

    var automationNoticeExpiryTaskIsActiveForTesting: Bool {
        guard let task = cleanupBag.automationNoticeExpiryTask else { return false }
        return !task.isCancelled
    }

    var automationNoticeExpiryTaskNoticeIDForTesting: UUID? {
        cleanupBag.automationNoticeExpiryTaskNoticeID
    }

    func expireAutomationNoticeFromScheduledTaskForTesting(id: UUID) {
        expireAutomationNoticeFromScheduledTask(id: id)
    }

    func presentAutomationAlert(
        title: String,
        message: String,
        action: String,
        primaryButton: String,
        secondaryButton: String,
        primaryAction: (() -> Void)?
    ) {
        performAutomationAlert(action: action) {
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.addButton(withTitle: primaryButton)
            alert.addButton(withTitle: secondaryButton)
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                primaryAction?()
            }
        }
    }

    private func performAutomationAlert(action: String, _ present: () -> Void) {
        guard canPresentAutomationAlert(action: action) else { return }
        isPresentingAutomationAlert = true
        defer {
            isPresentingAutomationAlert = false
            automationAlertSuppressionUntilByAction[action] = Date()
                .addingTimeInterval(automationAlertSuppressionWindow)
        }
        present()
    }

    private func canPresentAutomationAlert(action: String, now: Date = Date()) -> Bool {
        guard !isPresentingAutomationAlert else { return false }
        if let suppressionUntil = automationAlertSuppressionUntilByAction[action],
           now < suppressionUntil {
            return false
        }
        return true
    }

    func sanitizedAutomationFailureMessage(_ error: Error) -> String {
        AutomationFailureSanitizer.sanitizedMessage(from: error)
    }
}
