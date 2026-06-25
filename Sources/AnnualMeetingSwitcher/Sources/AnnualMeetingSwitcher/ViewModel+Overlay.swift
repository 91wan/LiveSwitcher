import SwiftUI
import Combine

// MARK: - Tier1: Overlay 叠层状态扩展

extension SwitcherViewModel {

    // MARK: - 倒计时方法

    func startCountdown(minutes: Int, seconds: Int, title: String = "活动即将开始") {
        guard let totalSeconds = OverlayUIState.countdownTotalSeconds(minutes: minutes, seconds: seconds),
              OverlayUIState.countdownDisabledReason(minutes: minutes, seconds: seconds, isLive: false) == nil else {
            return
        }
        startCountdown(seconds: totalSeconds, title: title)
    }

    /// 启动倒计时（秒数，标题）
    func startCountdown(seconds: Int, title: String = "活动即将开始") {
        guard OverlayUIState.countdownDisabledReason(totalSeconds: seconds, isLive: false) == nil else {
            return
        }

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        countdownTitle    = trimmedTitle.isEmpty ? "活动即将开始" : trimmedTitle
        countdownSeconds  = seconds
        isCountdownActive = true
        recordSupportEvent(kind: .countdownStarted, detail: "durationSeconds=\(seconds)")

        // 停止已有 Timer
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

    /// Advances countdown by one second. Kept as a named path so expiry behavior stays testable.
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

    /// 停止倒计时
    func stopCountdown() {
        let wasActive = isCountdownActive
        countdownTimer?.invalidate()
        countdownTimer    = nil
        isCountdownActive = false
        countdownSeconds  = 0
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

    func clearCountdownPresetDraft() {
        overlayComposerState.selectedKind = .countdown
        overlayComposerState.selectedCountdownPresetID = nil
        overlayComposerState.countdownTitleDraft = CountdownPreset.defaultTitle
        overlayComposerState.countdownMinutesDraft = 10
        overlayComposerState.countdownSecondsDraft = 0
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

    // MARK: - 游动字幕方法

    @discardableResult
    func saveTickerPresetFromDraft() -> Bool {
        saveTickerPreset(
            text: overlayComposerState.tickerTextDraft,
            speedIndex: overlayComposerState.tickerSpeedIndex,
            updatingSelectedPreset: true
        )
    }

    @discardableResult
    func saveTickerPreset(text: String, speedIndex: Int) -> Bool {
        saveTickerPreset(text: text, speedIndex: speedIndex, updatingSelectedPreset: false)
    }

    @discardableResult
    private func saveTickerPreset(text: String, speedIndex: Int, updatingSelectedPreset: Bool) -> Bool {
        let selectedID = overlayComposerState.selectedTickerPresetID
        let existingIndex = updatingSelectedPreset ? selectedID.flatMap { selectedID in
            tickerPresets.firstIndex { $0.id == selectedID }
        } : nil
        let orderIndex = existingIndex.map { tickerPresets[$0].orderIndex } ?? tickerPresets.count
        let presetID = existingIndex.map { tickerPresets[$0].id } ?? UUID()

        guard let preset = TickerPreset.make(
            id: presetID,
            text: text,
            speedIndex: speedIndex,
            orderIndex: orderIndex
        ) else {
            return false
        }

        if let existingIndex {
            tickerPresets[existingIndex] = preset
        } else {
            tickerPresets.append(preset)
        }
        tickerPresets = TickerPreset.normalized(tickerPresets)
        loadTickerPreset(preset)
        saveData()
        return true
    }

    func loadTickerPreset(_ preset: TickerPreset) {
        guard let storedPreset = tickerPresets.first(where: { $0.id == preset.id }) ?? TickerPreset.make(
            id: preset.id,
            text: preset.text,
            speedIndex: preset.speedIndex,
            orderIndex: preset.orderIndex
        ) else {
            return
        }

        overlayComposerState.selectedKind = .ticker
        overlayComposerState.selectedTickerPresetID = storedPreset.id
        overlayComposerState.tickerTextDraft = storedPreset.text
        overlayComposerState.tickerSpeedIndex = storedPreset.speedIndex
        tickerSpeed = OverlaySpeedSelection.speed(at: storedPreset.speedIndex)
    }

    func clearTickerPresetDraft() {
        overlayComposerState.selectedKind = .ticker
        overlayComposerState.selectedTickerPresetID = nil
        overlayComposerState.tickerTextDraft = TickerPreset.defaultText
        overlayComposerState.tickerSpeedIndex = 1
        tickerSpeed = OverlaySpeedSelection.speed(at: 1)
    }

    func deleteTickerPreset(id: UUID) {
        tickerPresets.removeAll { $0.id == id }
        tickerPresets = TickerPreset.normalized(tickerPresets)
        if overlayComposerState.selectedTickerPresetID == id {
            clearTickerPresetDraft()
        }
        saveData()
    }

    func startTickerPreset(_ preset: TickerPreset) {
        guard let sanitizedPreset = TickerPreset.make(
            id: preset.id,
            text: preset.text,
            speedIndex: preset.speedIndex,
            orderIndex: preset.orderIndex
        ) else {
            return
        }
        tickerSpeed = OverlaySpeedSelection.speed(at: sanitizedPreset.speedIndex)
        startTicker(text: sanitizedPreset.text)
    }

    /// 启动游动字幕
    func startTicker(text: String) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        tickerText     = trimmedText
        isTickerActive = true
        recordSupportEvent(kind: .tickerStarted, detail: "state=started")
    }

    /// 停止游动字幕
    func stopTicker() {
        let wasActive = isTickerActive
        isTickerActive = false
        if wasActive {
            recordSupportEvent(kind: .tickerStopped, detail: "state=stopped")
        }
    }

    // MARK: - V27: 下三分之一条方法

    @discardableResult
    func saveLowerThirdPresetFromDraft() -> Bool {
        saveLowerThirdPreset(
            name: overlayComposerState.lowerThirdNameDraft,
            role: overlayComposerState.lowerThirdRoleDraft,
            organization: overlayComposerState.lowerThirdOrganizationDraft,
            updatingSelectedPreset: true
        )
    }

    @discardableResult
    func saveLowerThirdPreset(name: String, role: String, organization: String) -> Bool {
        saveLowerThirdPreset(name: name, role: role, organization: organization, updatingSelectedPreset: false)
    }

    @discardableResult
    private func saveLowerThirdPreset(
        name: String,
        role: String,
        organization: String,
        updatingSelectedPreset: Bool
    ) -> Bool {
        let selectedID = overlayComposerState.selectedLowerThirdPresetID
        let existingIndex = updatingSelectedPreset ? selectedID.flatMap { selectedID in
            lowerThirdPresets.firstIndex { $0.id == selectedID }
        } : nil
        let orderIndex = existingIndex.map { lowerThirdPresets[$0].orderIndex } ?? lowerThirdPresets.count
        let presetID = existingIndex.map { lowerThirdPresets[$0].id } ?? UUID()

        guard let preset = LowerThirdPreset.make(
            id: presetID,
            name: name,
            role: role,
            organization: organization,
            orderIndex: orderIndex
        ) else {
            return false
        }

        if let existingIndex {
            lowerThirdPresets[existingIndex] = preset
        } else {
            lowerThirdPresets.append(preset)
        }
        lowerThirdPresets = LowerThirdPreset.normalized(lowerThirdPresets)
        loadLowerThirdPreset(preset)
        saveData()
        return true
    }

    func loadLowerThirdPreset(_ preset: LowerThirdPreset) {
        guard let storedPreset = lowerThirdPresets.first(where: { $0.id == preset.id }) ?? LowerThirdPreset.make(
            id: preset.id,
            name: preset.name,
            role: preset.role,
            organization: preset.organization,
            orderIndex: preset.orderIndex
        ) else {
            return
        }

        overlayComposerState.selectedKind = .lowerThird
        overlayComposerState.selectedLowerThirdPresetID = storedPreset.id
        overlayComposerState.lowerThirdNameDraft = storedPreset.name
        overlayComposerState.lowerThirdRoleDraft = storedPreset.role
        overlayComposerState.lowerThirdOrganizationDraft = storedPreset.organization
    }

    func clearLowerThirdPresetDraft() {
        overlayComposerState.selectedKind = .lowerThird
        overlayComposerState.selectedLowerThirdPresetID = nil
        overlayComposerState.lowerThirdNameDraft = ""
        overlayComposerState.lowerThirdRoleDraft = ""
        overlayComposerState.lowerThirdOrganizationDraft = ""
    }

    func deleteLowerThirdPreset(id: UUID) {
        lowerThirdPresets.removeAll { $0.id == id }
        lowerThirdPresets = LowerThirdPreset.normalized(lowerThirdPresets)
        if overlayComposerState.selectedLowerThirdPresetID == id {
            clearLowerThirdPresetDraft()
        }
        saveData()
    }

    @discardableResult
    func importLowerThirdPresets(
        _ presets: [LowerThirdPreset],
        duplicatePolicy: SpeakerImportDuplicatePolicy = .skipExisting
    ) -> SpeakerImportResult {
        let result = SpeakerImportService.merge(
            imported: presets,
            into: lowerThirdPresets,
            duplicatePolicy: duplicatePolicy
        )
        lowerThirdPresets = result.presets
        saveData()
        return result
    }

    @discardableResult
    func importLowerThirdSpeakersFromClipboardText(
        _ text: String,
        duplicatePolicy: SpeakerImportDuplicatePolicy = .skipExisting
    ) -> SpeakerImportResult? {
        guard let presets = try? SpeakerImportService.parse(text: text) else {
            return nil
        }
        return importLowerThirdPresets(presets, duplicatePolicy: duplicatePolicy)
    }

    func exportLowerThirdPresetsCSV() -> String {
        SpeakerImportService.exportCSV(lowerThirdPresets)
    }

    func showLowerThirdPreset(_ preset: LowerThirdPreset) {
        guard let sanitizedPreset = LowerThirdPreset.make(
            id: preset.id,
            name: preset.name,
            role: preset.role,
            organization: preset.organization,
            orderIndex: preset.orderIndex
        ) else {
            return
        }
        showLowerThird(
            name: sanitizedPreset.name,
            role: sanitizedPreset.role,
            organization: sanitizedPreset.organization
        )
    }

    /// 显示人名条（弹簧飞入）
    func showLowerThird(name: String, role: String, organization: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        lowerThirdName = trimmedName
        lowerThirdRole = role.trimmingCharacters(in: .whitespacesAndNewlines)
        lowerThirdOrganization = organization.trimmingCharacters(in: .whitespacesAndNewlines)
        isLowerThirdVisible = true
        recordSupportEvent(kind: .lowerThirdShown, detail: "state=shown")
    }

    /// 隐藏人名条（退场动画后消失）
    func dismissLowerThird() {
        let wasVisible = isLowerThirdVisible
        isLowerThirdVisible = false
        if wasVisible {
            recordSupportEvent(kind: .lowerThirdHidden, detail: "state=hidden")
        }
    }

    /// 一键清空所有大屏叠层
    func clearAllOverlays() {
        stopCountdown()
        stopTicker()
        dismissLowerThird()
        lowerThirdName = ""
        lowerThirdRole = ""
        lowerThirdOrganization = ""
        recordSupportEvent(kind: .overlaysCleared, detail: "state=cleared")
    }
}
