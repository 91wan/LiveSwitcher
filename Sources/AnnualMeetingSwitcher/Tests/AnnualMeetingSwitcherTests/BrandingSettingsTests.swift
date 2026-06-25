import AppKit
import XCTest
@testable import LiveSwitcher

final class BrandingSettingsTests: XCTestCase {
    func testBrandingDisplayNamePolicyNormalizesAndFallsBackToAppName() {
        XCTAssertEqual(
            BrandingDisplayNamePolicy.normalizedDisplayName(from: "  示例\n\t科技\u{0007}有限公司  "),
            "示例 科技 有限公司"
        )
        XCTAssertEqual(
            BrandingDisplayNamePolicy.effectiveDisplayName(for: ""),
            AppConfiguration.appName
        )
        XCTAssertEqual(
            BrandingDisplayNamePolicy.effectiveDisplayName(for: "示例科技"),
            "示例科技"
        )
    }

    func testBrandingDisplayNamePolicyRejectsOverlongGraphemeDraftWithoutTruncating() {
        let thirtyTwo = String(repeating: "中", count: 32)
        let thirtyThree = String(repeating: "中", count: 33)
        let familyEmoji = String(repeating: "👨‍👩‍👧‍👦", count: 32)

        XCTAssertNil(BrandingDisplayNamePolicy.validationMessage(for: thirtyTwo))
        XCTAssertNil(BrandingDisplayNamePolicy.validationMessage(for: familyEmoji))
        XCTAssertNotNil(BrandingDisplayNamePolicy.validationMessage(for: thirtyThree))
        XCTAssertEqual(BrandingDisplayNamePolicy.normalizedDisplayName(from: thirtyThree).count, 33)
    }

    func testConsoleBrandingModelBuildsTitlesFromEffectiveBrand() {
        XCTAssertEqual(
            ConsoleBrandingModel.title(brandName: "示例科技", mode: .setup, tab: .preview),
            "示例科技 · 导播台"
        )
        XCTAssertEqual(
            ConsoleBrandingModel.title(brandName: "示例科技", mode: .setup, tab: .audioMixer),
            "示例科技 · 音频"
        )
        XCTAssertEqual(
            ConsoleBrandingModel.title(brandName: "示例科技", mode: .setup, tab: .overlays),
            "示例科技 · 叠层"
        )
        XCTAssertEqual(
            ConsoleBrandingModel.title(brandName: "示例科技", mode: .live, tab: .preview),
            "示例科技 · LIVE"
        )
        XCTAssertEqual(
            ConsoleBrandingModel.title(brandName: "", mode: .setup, tab: .preview),
            "LiveSwitcher · 导播台"
        )
    }

    func testPersistenceSavesLoadsAndMigratesBrandingPreferences() throws {
        let defaults = try makeDefaults()
        let logoURL = try makeTempPNG()
        var state = SwitcherPersistentState()
        state.companyDisplayName = "机密客户甲有限公司"
        state.cornerLogoURL = logoURL
        state.cornerLogoPosition = .bottomLeft
        state.isCornerLogoVisible = false

        SwitcherPersistenceStore(userDefaults: defaults).save(state)
        let loaded = SwitcherPersistenceStore(userDefaults: defaults).load().state

        XCTAssertEqual(defaults.string(forKey: "branding.companyName"), "机密客户甲有限公司")
        XCTAssertEqual(defaults.bool(forKey: "cornerLogo.isVisible"), false)
        XCTAssertEqual(loaded.companyDisplayName, "机密客户甲有限公司")
        XCTAssertEqual(loaded.cornerLogoURL, logoURL)
        XCTAssertEqual(loaded.cornerLogoPosition, .bottomLeft)
        XCTAssertFalse(loaded.isCornerLogoVisible)

        let migratedWithLogo = try makeDefaults()
        let legacyLogo = try makeTempPNG()
        migratedWithLogo.set(legacyLogo.path, forKey: "cornerLogo_path")
        let migratedState = SwitcherPersistenceStore(userDefaults: migratedWithLogo).load().state
        XCTAssertEqual(migratedState.cornerLogoURL, legacyLogo)
        XCTAssertTrue(migratedState.isCornerLogoVisible)

        let migratedWithoutLogo = try makeDefaults()
        let emptyState = SwitcherPersistenceStore(userDefaults: migratedWithoutLogo).load().state
        XCTAssertNil(emptyState.cornerLogoURL)
        XCTAssertFalse(emptyState.isCornerLogoVisible)
    }

    func testRuntimePreferenceReducerPersistsBrandingWithoutLeakingRawCompanyNameIntoActionName() {
        var state = LiveRuntimeState()
        var effects: [LiveRuntimeEffect] = []

        PreferencesRuntimeReducer.setCompanyDisplayName(
            "机密客户甲有限公司",
            state: &state,
            effects: &effects
        )
        PreferencesRuntimeReducer.setCornerLogoVisible(false, state: &state, effects: &effects)

        XCTAssertEqual(state.preferences.companyDisplayName, "机密客户甲有限公司")
        XCTAssertFalse(state.preferences.isCornerLogoVisible)
        XCTAssertEqual(
            effects,
            [
                .saveCompanyDisplayName("机密客户甲有限公司"),
                .saveCornerLogoVisible(false)
            ]
        )
        XCTAssertEqual(
            LiveRuntimeAction.operatorSetCompanyDisplayName("机密客户甲有限公司").redactedName,
            "operatorSetCompanyDisplayName"
        )
        XCTAssertFalse(
            LiveRuntimeAction.operatorSetCompanyDisplayName("机密客户甲有限公司")
                .redactedName
                .contains("机密客户甲有限公司")
        )
    }

    @MainActor
    func testViewModelLogoVisibilityTogglesWithoutClearingDecodedLogoOrReloading() async throws {
        let viewModel = makeViewModel()
        let url = try makeTempPNG()
        let image = NSImage(size: NSSize(width: 16, height: 16))
        let loader = CornerLogoLoaderProbe()
        viewModel.cornerLogoImageLoader = loader.load

        XCTAssertTrue(viewModel.setCornerLogo(url: url))
        await loader.waitForRequestCount(1)
        loader.complete(url: url, with: .success(image))
        await waitForLogoReady(viewModel, activeURL: url)
        XCTAssertTrue(viewModel.isCornerLogoVisible)

        viewModel.isCornerLogoVisible = false
        XCTAssertEqual(viewModel.cornerLogoURL, url)
        XCTAssertTrue(viewModel.cornerLogoImage === image)
        XCTAssertEqual(viewModel.cornerLogoLoadPhase, .ready(activeURL: url))

        viewModel.isCornerLogoVisible = true
        await Task.yield()
        XCTAssertEqual(loader.requestedURLs, [url])
        XCTAssertEqual(viewModel.cornerLogoURL, url)
        XCTAssertTrue(viewModel.cornerLogoImage === image)
    }

    @MainActor
    func testReplacingAndFailingLogoPreservesVisibilityState() async throws {
        let viewModel = makeViewModel()
        let oldURL = try makeTempPNG(named: "old.png")
        let newURL = try makeTempPNG(named: "new.png")
        let brokenURL = try makeTempPNG(named: "broken.png")
        let oldImage = NSImage(size: NSSize(width: 12, height: 12))
        let newImage = NSImage(size: NSSize(width: 18, height: 18))
        let loader = CornerLogoLoaderProbe()
        viewModel.cornerLogoImageLoader = loader.load

        XCTAssertTrue(viewModel.setCornerLogo(url: oldURL))
        await loader.waitForRequestCount(1)
        loader.complete(url: oldURL, with: .success(oldImage))
        await waitForLogoReady(viewModel, activeURL: oldURL)
        viewModel.isCornerLogoVisible = false

        XCTAssertTrue(viewModel.setCornerLogo(url: newURL))
        await loader.waitForRequestCount(2)
        loader.complete(url: newURL, with: .success(newImage))
        await waitForLogoReady(viewModel, activeURL: newURL)
        XCTAssertFalse(viewModel.isCornerLogoVisible)

        XCTAssertTrue(viewModel.setCornerLogo(url: brokenURL))
        await loader.waitForRequestCount(3)
        loader.complete(url: brokenURL, with: .failure(.decodeFailed))
        await waitForLogoFailure(viewModel)
        XCTAssertEqual(viewModel.cornerLogoURL, newURL)
        XCTAssertTrue(viewModel.cornerLogoImage === newImage)
        XCTAssertFalse(viewModel.isCornerLogoVisible)
    }

    func testOutputDisplayStateRequiresLogoVisibilityForLogoFrame() {
        let hidden = OutputDisplayState.make(
            currentHTMLURL: nil,
            isCountdownActive: false,
            isTickerActive: false,
            isLowerThirdVisible: false,
            lowerThirdName: "",
            lowerThirdRole: "",
            lowerThirdOrganization: "",
            isPanicMode: false,
            isFadeToBlackActive: false,
            cornerLogoPosition: .topRight,
            isCornerLogoVisible: false
        )
        let visible = OutputDisplayState.make(
            currentHTMLURL: nil,
            isCountdownActive: false,
            isTickerActive: false,
            isLowerThirdVisible: false,
            lowerThirdName: "",
            lowerThirdRole: "",
            lowerThirdOrganization: "",
            isPanicMode: false,
            isFadeToBlackActive: false,
            cornerLogoPosition: .topRight,
            isCornerLogoVisible: true
        )

        XCTAssertFalse(hidden.shouldRenderCornerLogo(hasDecodedImage: true))
        XCTAssertFalse(visible.shouldRenderCornerLogo(hasDecodedImage: false))
        XCTAssertTrue(visible.shouldRenderCornerLogo(hasDecodedImage: true))
    }

    func testBrandingSettingsDoNotLeakCompanyNameIntoSupportSurfaces() {
        let sensitiveName = "机密客户甲有限公司"
        var state = LiveRuntimeState()
        state.preferences.companyDisplayName = sensitiveName
        state.preferences.isCornerLogoVisible = true
        let action = LiveRuntimeAction.operatorSetCompanyDisplayName(sensitiveName)
        let report = LiveSupportReport.makePlainText(
            snapshot: diagnosticsSnapshot(),
            checks: [],
            events: [
                LiveSupportEvent(
                    timestamp: Date(timeIntervalSince1970: 1_790_000_000),
                    kind: .preflightAction,
                    detail: "company=\(sensitiveName)"
                )
            ],
            actionLog: [
                LiveRuntimeActionLogEntry(
                    timestamp: Date(timeIntervalSince1970: 1_790_000_001),
                    actionName: action.redactedName,
                    oldStateSummary: LiveRuntimeStore.testSummary(for: LiveRuntimeState()),
                    newStateSummary: LiveRuntimeStore.testSummary(for: state)
                )
            ],
            generatedAt: Date(timeIntervalSince1970: 1_790_000_002)
        )

        XCTAssertFalse(action.redactedName.contains(sensitiveName))
        XCTAssertFalse(LiveRuntimeStore.testSummary(for: state).contains(sensitiveName))
        XCTAssertFalse(report.contains(sensitiveName))
    }

    func testBrandingCardUsesDraftApplyResetAndLogoVisibilityControls() throws {
        let card = try sourceText(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/CornerLogoCard.swift"
        )

        XCTAssertTrue(card.contains("Text(\"品牌标识\")"))
        XCTAssertTrue(card.contains("公司名称"))
        XCTAssertTrue(card.contains("应用"))
        XCTAssertTrue(card.contains("恢复默认"))
        XCTAssertTrue(card.contains("显示 Logo"))
        XCTAssertFalse(card.contains("Text(\"角标\")"))
        XCTAssertFalse(card.contains("StatusBadge(\"关闭\""))
    }

    private func makeDefaults() throws -> UserDefaults {
        let suiteName = "BrandingSettingsTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    @MainActor
    private func makeViewModel() -> SwitcherViewModel {
        let defaults = UserDefaults(suiteName: "BrandingSettingsTests.vm.\(UUID().uuidString)")!
        defaults.removePersistentDomain(forName: defaults.description)
        return SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            userDefaults: defaults
        )
    }

    private func makeTempPNG(named name: String = "logo.png") throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BrandingSettingsTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(name)
        let image = NSImage(size: NSSize(width: 8, height: 8))
        image.lockFocus()
        NSColor.systemBlue.setFill()
        NSRect(x: 0, y: 0, width: 8, height: 8).fill()
        image.unlockFocus()
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: try XCTUnwrap(image.tiffRepresentation)))
        let data = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        try data.write(to: url)
        return url
    }

    @MainActor
    private func waitForLogoReady(_ viewModel: SwitcherViewModel, activeURL: URL) async {
        for _ in 0..<100 {
            if viewModel.cornerLogoLoadPhase == .ready(activeURL: activeURL) {
                return
            }
            await Task.yield()
        }
        XCTFail("Corner logo did not become ready")
    }

    @MainActor
    private func waitForLogoFailure(_ viewModel: SwitcherViewModel) async {
        for _ in 0..<100 {
            if case .failed = viewModel.cornerLogoLoadPhase {
                return
            }
            await Task.yield()
        }
        XCTFail("Corner logo did not fail")
    }

    private func diagnosticsSnapshot() -> LiveDiagnosticsSnapshot {
        LiveDiagnosticsSnapshot(
            appVersion: "0.4.0",
            operatingSystem: "macOS Test",
            architecture: "arm64-test",
            preflight: LivePreflightSnapshot(
                appVersion: "0.4.0",
                hasExternalDisplay: true,
                isBroadcasting: false,
                broadcastSafetyNotice: nil,
                programItemCount: 0,
                currentProgramTitle: nil,
                currentProgramSource: nil,
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

@MainActor
private final class CornerLogoLoaderProbe {
    private struct QueuedResult {
        let url: URL
        let result: Result<NSImage, CornerLogoLoadFailure>
    }

    private(set) var requestedURLs: [URL] = []
    private var queuedResults: [QueuedResult] = []

    func load(_ url: URL) async -> Result<NSImage, CornerLogoLoadFailure> {
        requestedURLs.append(url)
        while true {
            if Task.isCancelled {
                return .failure(.decodeFailed)
            }
            if let index = queuedResults.firstIndex(where: { $0.url == url }) {
                return queuedResults.remove(at: index).result
            }
            await Task.yield()
        }
    }

    func waitForRequestCount(_ count: Int) async {
        while requestedURLs.count < count {
            await Task.yield()
        }
    }

    func complete(url: URL, with result: Result<NSImage, CornerLogoLoadFailure>) {
        guard requestedURLs.contains(url) else {
            XCTFail("No pending request for \(url.lastPathComponent)")
            return
        }
        queuedResults.append(QueuedResult(url: url, result: result))
    }
}
