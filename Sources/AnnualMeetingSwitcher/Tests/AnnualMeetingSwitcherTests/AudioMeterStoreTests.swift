import XCTest
@testable import LiveSwitcher

@MainActor
final class AudioMeterStoreTests: XCTestCase {
    func testPolicyPublishesInitialAndResetLevels() {
        XCTAssertTrue(AudioMeterPublishPolicy.shouldPublishLevel(previous: nil, next: -24))
        XCTAssertTrue(AudioMeterPublishPolicy.shouldPublishLevel(previous: -24, next: nil))
        XCTAssertFalse(AudioMeterPublishPolicy.shouldPublishLevel(previous: nil, next: nil))
    }

    func testPolicyDedupesTinyMeterChanges() {
        XCTAssertFalse(AudioMeterPublishPolicy.shouldPublishLevel(previous: -18, next: -17.7))
        XCTAssertTrue(AudioMeterPublishPolicy.shouldPublishLevel(previous: -18, next: -17.3))
    }

    func testStoreDedupesSmallBGMLevelChanges() {
        let store = AudioMeterStore()

        store.updateBGMRealtimeLevel(-20)
        XCTAssertEqual(store.bgmRealtimeLevelDB, -20)

        store.updateBGMRealtimeLevel(-19.8)
        XCTAssertEqual(store.bgmRealtimeLevelDB, -20)

        store.updateBGMRealtimeLevel(-19.2)
        XCTAssertEqual(store.bgmRealtimeLevelDB, -19.2)

        store.resetBGMRealtimeLevel()
        XCTAssertNil(store.bgmRealtimeLevelDB)
    }

    func testViewModelDoesNotExposeBGMRealtimeLevelAsObservedState() throws {
        let source = try sourceText("ViewModel.swift")

        XCTAssertTrue(source.contains("@ObservationIgnored var bgmRealtimeLevelDB"))
        XCTAssertTrue(source.contains("@ObservationIgnored let audioMeterStore"))
    }

    func testLiveAudioStripObservesDedicatedMeterStore() throws {
        let source = try sourceText("Views/LiveModeView.swift")

        XCTAssertTrue(source.contains("@ObservedObject var avCoordinator: AVPlayerCoordinator"))
        XCTAssertTrue(source.contains("avCoordinator: viewModel.avCoordinator"))
        XCTAssertTrue(source.contains("realtimeDB: avCoordinator.realtimeLevelDB"))
        XCTAssertFalse(source.contains("realtimeDB: viewModel.avCoordinator.realtimeLevelDB"))
        XCTAssertTrue(source.contains("@ObservedObject var bgmMeterStore: AudioMeterStore"))
        XCTAssertTrue(source.contains("realtimeDB: bgmMeterStore.bgmRealtimeLevelDB"))
        XCTAssertFalse(source.contains("realtimeDB: viewModel.bgmRealtimeLevelDB"))
    }

    func testAVPlayerCoordinatorKeepsMediaMeterTapAliveAfterLoadAndClearsOnStop() {
        let coordinator = AVPlayerCoordinator()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        FileManager.default.createFile(atPath: url.path, contents: Data())
        defer { try? FileManager.default.removeItem(at: url) }

        coordinator.load(url: url)
        XCTAssertTrue(coordinator.hasActiveMediaAudioMeterTap)

        coordinator.stop()
        XCTAssertFalse(coordinator.hasActiveMediaAudioMeterTap)
    }

    func testAVPlayerCoordinatorReplacesMeterTapOnSecondLoadAndClearsOnShutdown() {
        let coordinator = AVPlayerCoordinator()
        let firstURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        let secondURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        FileManager.default.createFile(atPath: firstURL.path, contents: Data())
        FileManager.default.createFile(atPath: secondURL.path, contents: Data())
        defer {
            try? FileManager.default.removeItem(at: firstURL)
            try? FileManager.default.removeItem(at: secondURL)
        }

        coordinator.load(url: firstURL)
        XCTAssertTrue(coordinator.hasActiveMediaAudioMeterTap)

        coordinator.load(url: secondURL)
        XCTAssertTrue(coordinator.hasActiveMediaAudioMeterTap)
        XCTAssertEqual(coordinator.currentURL, secondURL)

        coordinator.shutdown()
        XCTAssertFalse(coordinator.hasActiveMediaAudioMeterTap)
        XCTAssertFalse(coordinator.hasLoadedMedia)
    }

    private func sourceText(_ relativePath: String) throws -> String {
        try String(contentsOf: sourceURL(relativePath), encoding: .utf8)
    }

    private func sourceURL(_ relativePath: String) throws -> URL {
        var directory = URL(fileURLWithPath: #filePath)
        while directory.pathComponents.count > 1 {
            directory.deleteLastPathComponent()
            let candidate = directory
                .appendingPathComponent("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher")
                .appendingPathComponent(relativePath)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        throw XCTSkip("Could not locate \(relativePath) from test source path.")
    }
}
