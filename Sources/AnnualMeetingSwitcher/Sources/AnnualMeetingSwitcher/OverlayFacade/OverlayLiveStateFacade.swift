import Foundation

extension SwitcherViewModel {
    func showLowerThird(name: String, role: String, organization: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        lowerThirdName = trimmedName
        lowerThirdRole = role.trimmingCharacters(in: .whitespacesAndNewlines)
        lowerThirdOrganization = organization.trimmingCharacters(in: .whitespacesAndNewlines)
        isLowerThirdVisible = true
        recordSupportEvent(kind: .lowerThirdShown, detail: "state=shown")
    }

    func dismissLowerThird() {
        let wasVisible = isLowerThirdVisible
        isLowerThirdVisible = false
        if wasVisible {
            recordSupportEvent(kind: .lowerThirdHidden, detail: "state=hidden")
        }
    }

    func clearAllOverlays() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        isCountdownActive = false
        countdownSeconds = 0
        isTickerActive = false
        isLowerThirdVisible = false
        lowerThirdName = ""
        lowerThirdRole = ""
        lowerThirdOrganization = ""
        recordSupportEvent(kind: .overlaysCleared, detail: "state=cleared")
    }
}
