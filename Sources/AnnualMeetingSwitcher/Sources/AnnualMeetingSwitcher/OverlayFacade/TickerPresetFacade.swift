import Foundation

extension SwitcherViewModel {
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

    func startTicker(text: String) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        tickerText = trimmedText
        isTickerActive = true
        recordSupportEvent(kind: .tickerStarted, detail: "state=started")
    }

    func stopTicker() {
        let wasActive = isTickerActive
        isTickerActive = false
        if wasActive {
            recordSupportEvent(kind: .tickerStopped, detail: "state=stopped")
        }
    }
}
