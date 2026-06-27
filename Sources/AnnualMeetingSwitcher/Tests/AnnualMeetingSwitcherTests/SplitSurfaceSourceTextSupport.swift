enum SplitSurface: CaseIterable {
    case setupProgramRail
    case preflightPopover
    case safetyCockpit
    case bgmPlaylist
    case overlayControl

    fileprivate var relativePaths: [String] {
        switch self {
        case .setupProgramRail:
            return [
                "Views/Setup/LeftPanel.swift",
                "Views/Setup/ProgramRailHeader.swift",
                "Views/Setup/ProgramRailControls.swift",
                "Views/Setup/ProgramImportDropZone.swift",
                "Views/Setup/ProgramQueueList.swift",
                "Views/Setup/ProgramRailFooter.swift",
                "Views/Setup/ProgramDropHandler.swift"
            ]
        case .preflightPopover:
            return [
                "Views/Support/PreflightPopoverView.swift",
                "Views/Support/PreflightSummaryHeader.swift",
                "Views/Support/PreflightCheckList.swift",
                "Views/Support/PreflightCheckRow.swift",
                "Views/Support/PreflightPermissionSection.swift",
                "Views/Support/PreflightSupportActions.swift"
            ]
        case .safetyCockpit:
            return [
                "Views/Support/SafetyCockpitView.swift",
                "Views/Support/SafetyCockpitHeader.swift",
                "Views/Support/SafetyCockpitStatusGrid.swift",
                "Views/Support/SafetyCockpitRiskRow.swift",
                "Views/Support/SafetyCockpitSupportActions.swift"
            ]
        case .bgmPlaylist:
            return [
                "Views/BGMPlaylistPanel.swift",
                "Views/BGM/BGMPlaylistHeader.swift",
                "Views/BGM/BGMTransportControls.swift",
                "Views/BGM/BGMProgressRow.swift",
                "Views/BGM/BGMCategoryPicker.swift",
                "Views/BGM/BGMTrackList.swift",
                "Views/BGM/BGMTrackRow.swift",
                "Views/BGM/BGMImportControls.swift",
                "Views/BGM/BGMPanelStatusRow.swift"
            ]
        case .overlayControl:
            return [
                "Views/OverlayControlPanel.swift",
                "Views/Overlays/OverlayComposerPicker.swift",
                "Views/Overlays/OverlayComposerControls.swift",
                "Views/Overlays/LowerThirdComposerCard.swift",
                "Views/Overlays/CountdownComposerCard.swift",
                "Views/Overlays/TickerComposerCard.swift",
                "Views/Overlays/OverlayPresetList.swift",
                "Views/Overlays/OverlayLivePreviewColumn.swift",
                "Views/Overlays/OverlayActiveStatusCard.swift"
            ]
        }
    }
}

func sourceTextForSplitSurface(_ surface: SplitSurface) throws -> String {
    try surface.relativePaths
        .map { try sourceText($0) }
        .joined(separator: "\n")
}
