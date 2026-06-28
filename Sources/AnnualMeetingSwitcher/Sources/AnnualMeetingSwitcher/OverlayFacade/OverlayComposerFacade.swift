extension SwitcherViewModel {
    func clearCountdownPresetDraft() {
        overlayComposerState.selectedKind = .countdown
        overlayComposerState.selectedCountdownPresetID = nil
        overlayComposerState.countdownTitleDraft = CountdownPreset.defaultTitle
        overlayComposerState.countdownMinutesDraft = 10
        overlayComposerState.countdownSecondsDraft = 0
    }

    func clearTickerPresetDraft() {
        overlayComposerState.selectedKind = .ticker
        overlayComposerState.selectedTickerPresetID = nil
        overlayComposerState.tickerTextDraft = TickerPreset.defaultText
        overlayComposerState.tickerSpeedIndex = 1
        tickerSpeed = OverlaySpeedSelection.speed(at: 1)
    }

    func clearLowerThirdPresetDraft() {
        overlayComposerState.selectedKind = .lowerThird
        overlayComposerState.selectedLowerThirdPresetID = nil
        overlayComposerState.lowerThirdNameDraft = ""
        overlayComposerState.lowerThirdRoleDraft = ""
        overlayComposerState.lowerThirdOrganizationDraft = ""
    }
}
