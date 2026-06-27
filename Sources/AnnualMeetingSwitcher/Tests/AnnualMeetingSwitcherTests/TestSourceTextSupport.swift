import Foundation
import XCTest

func sourceText(_ relativePath: String, filePath: String = #filePath) throws -> String {
    if isLegacyLeftPanelPath(relativePath) {
        return try programSetupRailSurfaceText(filePath: filePath)
    }
    if isLegacyPreflightPopoverPath(relativePath) {
        return try preflightPopoverSurfaceText(filePath: filePath)
    }

    let root = try repositoryRoot(filePath: filePath)
    return try String(contentsOf: sourceURL(relativePath, repositoryRoot: root), encoding: .utf8)
}

func repositoryRoot(filePath: String = #filePath) throws -> URL {
    var directory = URL(fileURLWithPath: filePath)
    while directory.pathComponents.count > 1 {
        directory.deleteLastPathComponent()
        if FileManager.default.fileExists(atPath: directory.appendingPathComponent("docs").path) {
            return directory
        }
    }
    throw XCTSkip("Could not locate repository root from test source path.")
}

func sourceURL(_ relativePath: String, repositoryRoot root: URL) -> URL {
    if isLegacyLeftPanelPath(relativePath) {
        return root
            .appendingPathComponent("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/Setup/LeftPanel.swift")
    }
    if isLegacyPreflightPopoverPath(relativePath) {
        return root
            .appendingPathComponent("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/Support/PreflightPopoverView.swift")
    }

    let directCandidate = root.appendingPathComponent(relativePath)
    if FileManager.default.fileExists(atPath: directCandidate.path) {
        return directCandidate
    }

    let sourceRootCandidate = root
        .appendingPathComponent("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher")
        .appendingPathComponent(relativePath)
    if FileManager.default.fileExists(atPath: sourceRootCandidate.path) {
        return sourceRootCandidate
    }

    let legacySourcePrefix = "Sources/AnnualMeetingSwitcher/"
    if relativePath.hasPrefix(legacySourcePrefix) {
        let suffix = String(relativePath.dropFirst(legacySourcePrefix.count))
        let legacyCandidate = root
            .appendingPathComponent("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher")
            .appendingPathComponent(suffix)
        if FileManager.default.fileExists(atPath: legacyCandidate.path) {
            return legacyCandidate
        }
    }

    return directCandidate
}

func programSetupRailSurfaceText(filePath: String = #filePath) throws -> String {
    let files = [
        "Views/Setup/LeftPanel.swift",
        "Views/Setup/ProgramRailHeader.swift",
        "Views/Setup/ProgramRailControls.swift",
        "Views/Setup/ProgramImportDropZone.swift",
        "Views/Setup/ProgramQueueList.swift",
        "Views/Setup/ProgramRailFooter.swift",
        "Views/Setup/ProgramDropHandler.swift"
    ]

    return try files
        .map { try sourceText($0, filePath: filePath) }
        .joined(separator: "\n")
}

private func isLegacyLeftPanelPath(_ relativePath: String) -> Bool {
    relativePath == "Views/LeftPanel.swift"
        || relativePath == "Sources/AnnualMeetingSwitcher/Views/LeftPanel.swift"
        || relativePath == "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/LeftPanel.swift"
}

func preflightPopoverSurfaceText(filePath: String = #filePath) throws -> String {
    let files = [
        "Views/Support/PreflightPopoverView.swift",
        "Views/Support/PreflightSummaryHeader.swift",
        "Views/Support/PreflightCheckList.swift",
        "Views/Support/PreflightCheckRow.swift",
        "Views/Support/PreflightPermissionSection.swift",
        "Views/Support/PreflightSupportActions.swift"
    ]

    return try files
        .map { try sourceText($0, filePath: filePath) }
        .joined(separator: "\n")
}

private func isLegacyPreflightPopoverPath(_ relativePath: String) -> Bool {
    relativePath == "Views/PreflightPopoverView.swift"
        || relativePath == "Sources/AnnualMeetingSwitcher/Views/PreflightPopoverView.swift"
        || relativePath == "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/PreflightPopoverView.swift"
}

func bgmPlaylistSurfaceText(filePath: String = #filePath) throws -> String {
    let files = [
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

    return try files
        .map { try sourceText($0, filePath: filePath) }
        .joined(separator: "\n")
}

func overlayControlSurfaceText(filePath: String = #filePath) throws -> String {
    let files = [
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

    return try files
        .map { try sourceText($0, filePath: filePath) }
        .joined(separator: "\n")
}
