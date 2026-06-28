extension SwitcherViewModel {
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
}
