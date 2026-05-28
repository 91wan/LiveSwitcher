import XCTest
@testable import LiveSwitcher

final class LiveSupportReportPrivacyTests: XCTestCase {
    func testSupportReportUsesCallerProvidedChecksInOrderAndSanitizesThem() {
        let diagnostics = diagnosticsSnapshot(currentProgramTitle: "Client Show.mp4")
        let checks = [
            LivePreflightCheck(
                id: "custom.operator-review",
                group: .controls,
                status: .warn,
                title: "Custom operator review",
                message: "Review /Users/" + "operator/Show/Agenda.html before going live.",
                actionLabel: "Open \"Opening Video.mp4\"",
                actionKind: .manualReview
            ),
            LivePreflightCheck(
                id: "custom.display-gate",
                group: .controls,
                status: .fail,
                title: "Custom display gate",
                message: "Blocked Sponsor Wall.jpg until display owner signs off.",
                actionLabel: "Fix display",
                actionKind: .needsHardware
            )
        ]

        let report = LiveSupportReport.makePlainText(
            snapshot: diagnostics,
            checks: checks,
            events: [],
            generatedAt: Date(timeIntervalSince1970: 1_790_000_000)
        )

        XCTAssertTrue(report.contains("custom.operator-review"))
        XCTAssertTrue(report.contains("custom.display-gate"))
        XCTAssertTrue(report.contains("Custom operator review"))
        XCTAssertTrue(report.contains("Custom display gate"))
        XCTAssertLessThan(
            report.range(of: "custom.operator-review")!.lowerBound,
            report.range(of: "custom.display-gate")!.lowerBound
        )
        XCTAssertTrue(report.contains("[path redacted]"))
        XCTAssertTrue(report.contains("[filename redacted]"))
        XCTAssertFalse(report.localizedStandardContains("/Users/"))
        XCTAssertFalse(report.localizedStandardContains("Agenda.html"))
        XCTAssertFalse(report.localizedStandardContains("Opening Video.mp4"))
        XCTAssertFalse(report.localizedStandardContains("Sponsor Wall.jpg"))
        XCTAssertFalse(report.localizedStandardContains("Client Show.mp4"))
        XCTAssertTrue(report.contains("Current program: selected"))
    }

    func testSupportRedactorRedactsExpandedFilenameSurfaceWithoutDroppingEventSemantics() {
        let smartQuotedImage = "\u{201C}Customer Logo.png\u{201D}"
        let text = [
            "projection.fail.closed: loaded \"Opening Video.mp4\" and 'Agenda.html'",
            "wallpaper \(smartQuotedImage) from file:///Users/" + "operator/Show/Sponsor%20Wall.jpg",
            "fallback path /tmp/live-switcher/Client Deck.pptx",
            "app bundle /Applications/LiveSwitcher.app/Contents/MacOS/LiveSwitcher",
            "cache /var/folders/gm/live-switcher/Sponsor Wall.jpg",
            "settings ~/Library/Application Support/LiveSwitcher/Agenda.html"
        ].joined(separator: "\n")

        let redacted = LiveSupportRedactor.safeText(text)

        XCTAssertTrue(redacted.contains("projection.fail.closed"))
        XCTAssertTrue(redacted.contains("loaded"))
        XCTAssertTrue(redacted.contains("[filename redacted]"))
        XCTAssertTrue(redacted.contains("[path redacted]"))
        XCTAssertFalse(redacted.localizedStandardContains("Opening Video.mp4"))
        XCTAssertFalse(redacted.localizedStandardContains("Agenda.html"))
        XCTAssertFalse(redacted.localizedStandardContains("Customer Logo.png"))
        XCTAssertFalse(redacted.localizedStandardContains("Sponsor%20Wall.jpg"))
        XCTAssertFalse(redacted.localizedStandardContains("Client Deck.pptx"))
        XCTAssertFalse(redacted.localizedStandardContains("file://"))
        XCTAssertFalse(redacted.localizedStandardContains("/Users/"))
        XCTAssertFalse(redacted.localizedStandardContains("/tmp/"))
        XCTAssertFalse(redacted.localizedStandardContains("/Applications/"))
        XCTAssertFalse(redacted.localizedStandardContains("/var/folders/"))
        XCTAssertFalse(redacted.localizedStandardContains("~/Library/"))
    }

    func testAppleScriptFailureEventIsRetainedAndSanitized() {
        let report = LiveSupportReport.makePlainText(
            snapshot: diagnosticsSnapshot(),
            checks: [],
            events: [
                LiveSupportEvent(
                    timestamp: Date(timeIntervalSince1970: 1_790_000_000),
                    kind: .appleScriptFailed,
                    detail: "action=wps.open,error=/Users/operator/Show/Agenda.html failed"
                )
            ],
            generatedAt: Date(timeIntervalSince1970: 1_790_000_001)
        )

        XCTAssertTrue(report.contains("applescript.failed"))
        XCTAssertTrue(report.contains("action=wps.open"))
        XCTAssertTrue(report.contains("[path redacted]"))
        XCTAssertFalse(report.localizedStandardContains("/Users/"))
        XCTAssertFalse(report.localizedStandardContains("Agenda.html"))
    }

    private func diagnosticsSnapshot(currentProgramTitle: String? = nil) -> LiveDiagnosticsSnapshot {
        LiveDiagnosticsSnapshot(
            appVersion: "0.4.0",
            operatingSystem: "macOS Test",
            architecture: "arm64-test",
            preflight: LivePreflightSnapshot(
                appVersion: "0.4.0",
                hasExternalDisplay: true,
                isBroadcasting: false,
                broadcastSafetyNotice: nil,
                programItemCount: currentProgramTitle == nil ? 0 : 1,
                currentProgramTitle: currentProgramTitle,
                currentProgramSource: currentProgramTitle == nil ? nil : "Media",
                bgmItemCount: 0,
                isBGMPlaying: false,
                isBGMAudioTakeoverActive: false,
                isSpeakerMode: false,
                isPanicMode: false,
                isPageInterceptEnabled: false,
                activeOverlayCount: 0,
                wallpaperCount: 0,
                autoPlayNextVideoOnEnd: false,
                effectiveMediaVolume: 0.8,
                effectiveBGMVolume: 0.5
            )
        )
    }
}
