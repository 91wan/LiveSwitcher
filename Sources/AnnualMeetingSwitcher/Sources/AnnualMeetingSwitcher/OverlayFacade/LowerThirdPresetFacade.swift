import Foundation

extension SwitcherViewModel {
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

    func deleteLowerThirdPreset(id: UUID) {
        lowerThirdPresets.removeAll { $0.id == id }
        lowerThirdPresets = LowerThirdPreset.normalized(lowerThirdPresets)
        if overlayComposerState.selectedLowerThirdPresetID == id {
            clearLowerThirdPresetDraft()
        }
        saveData()
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
}
