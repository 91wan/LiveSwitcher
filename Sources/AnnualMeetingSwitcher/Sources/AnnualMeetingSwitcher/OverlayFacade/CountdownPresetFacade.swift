import Foundation

extension SwitcherViewModel {
    func startCountdown(minutes: Int, seconds: Int, title: String = "活动即将开始") {
        guard let totalSeconds = OverlayUIState.countdownTotalSeconds(minutes: minutes, seconds: seconds),
              OverlayUIState.countdownDisabledReason(minutes: minutes, seconds: seconds, isLive: false) == nil else {
            return
        }
        startCountdown(seconds: totalSeconds, title: title)
    }

    func startCountdown(seconds: Int, title: String = "活动即将开始") {
        guard OverlayUIState.countdownDisabledReason(totalSeconds: seconds, isLive: false) == nil else {
            return
        }

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        countdownTitle = trimmedTitle.isEmpty ? "活动即将开始" : trimmedTitle
        countdownSeconds = seconds
        isCountdownActive = true
        recordSupportEvent(kind: .countdownStarted, detail: "durationSeconds=\(seconds)")

        countdownTimer?.invalidate()

        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] t in
            Task { @MainActor in
                guard let self else {
                    t.invalidate()
                    return
                }
                self.countdownTick()
            }
        }
        countdownTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func countdownTick() {
        guard isCountdownActive else {
            countdownTimer?.invalidate()
            countdownTimer = nil
            countdownSeconds = 0
            return
        }

        guard countdownSeconds > 1 else {
            stopCountdown()
            return
        }

        countdownSeconds -= 1
    }

    func stopCountdown() {
        let wasActive = isCountdownActive
        countdownTimer?.invalidate()
        countdownTimer = nil
        isCountdownActive = false
        countdownSeconds = 0
        if wasActive {
            recordSupportEvent(kind: .countdownStopped, detail: "state=stopped")
        }
    }

    @discardableResult
    func saveCountdownPresetFromDraft() -> Bool {
        guard let totalSeconds = OverlayUIState.countdownTotalSeconds(
            minutes: overlayComposerState.countdownMinutesDraft,
            seconds: overlayComposerState.countdownSecondsDraft
        ) else {
            return false
        }
        return saveCountdownPreset(
            title: overlayComposerState.countdownTitleDraft,
            totalSeconds: totalSeconds,
            updatingSelectedPreset: true
        )
    }

    @discardableResult
    func saveCountdownPreset(title: String, totalSeconds: Int) -> Bool {
        saveCountdownPreset(title: title, totalSeconds: totalSeconds, updatingSelectedPreset: false)
    }

    @discardableResult
    private func saveCountdownPreset(title: String, totalSeconds: Int, updatingSelectedPreset: Bool) -> Bool {
        let selectedID = overlayComposerState.selectedCountdownPresetID
        let existingIndex = updatingSelectedPreset ? selectedID.flatMap { selectedID in
            countdownPresets.firstIndex { $0.id == selectedID }
        } : nil
        let orderIndex = existingIndex.map { countdownPresets[$0].orderIndex } ?? countdownPresets.count
        let presetID = existingIndex.map { countdownPresets[$0].id } ?? UUID()

        guard let preset = CountdownPreset.make(
            id: presetID,
            title: title,
            totalSeconds: totalSeconds,
            orderIndex: orderIndex
        ) else {
            return false
        }

        if let existingIndex {
            countdownPresets[existingIndex] = preset
        } else {
            countdownPresets.append(preset)
        }
        countdownPresets = CountdownPreset.normalized(countdownPresets)
        loadCountdownPreset(preset)
        saveData()
        return true
    }

    func loadCountdownPreset(_ preset: CountdownPreset) {
        guard let storedPreset = countdownPresets.first(where: { $0.id == preset.id }) ?? CountdownPreset.make(
            id: preset.id,
            title: preset.title,
            totalSeconds: preset.totalSeconds,
            orderIndex: preset.orderIndex
        ) else {
            return
        }

        overlayComposerState.selectedKind = .countdown
        overlayComposerState.selectedCountdownPresetID = storedPreset.id
        overlayComposerState.countdownTitleDraft = storedPreset.title
        overlayComposerState.countdownMinutesDraft = storedPreset.totalSeconds / 60
        overlayComposerState.countdownSecondsDraft = storedPreset.totalSeconds % 60
    }

    func deleteCountdownPreset(id: UUID) {
        countdownPresets.removeAll { $0.id == id }
        countdownPresets = CountdownPreset.normalized(countdownPresets)
        if overlayComposerState.selectedCountdownPresetID == id {
            clearCountdownPresetDraft()
        }
        saveData()
    }

    func startCountdownPreset(_ preset: CountdownPreset) {
        guard let sanitizedPreset = CountdownPreset.make(
            id: preset.id,
            title: preset.title,
            totalSeconds: preset.totalSeconds,
            orderIndex: preset.orderIndex
        ) else {
            return
        }
        startCountdown(seconds: sanitizedPreset.totalSeconds, title: sanitizedPreset.title)
    }
}
