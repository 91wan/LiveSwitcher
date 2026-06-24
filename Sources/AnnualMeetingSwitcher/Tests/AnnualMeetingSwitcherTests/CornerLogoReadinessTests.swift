import AppKit
import XCTest
@testable import LiveSwitcher

@MainActor
final class CornerLogoReadinessTests: XCTestCase {
    func testSelectingNewLogoKeepsCurrentLogoUntilCandidateDecodeSucceeds() async throws {
        let viewModel = makeViewModel()
        let oldURL = temporaryImageURL(named: "old.png")
        let newURL = temporaryImageURL(named: "new.png")
        let oldImage = NSImage(size: NSSize(width: 12, height: 12))
        let newImage = NSImage(size: NSSize(width: 20, height: 20))
        let loader = CornerLogoLoaderProbe()
        viewModel.cornerLogoURL = oldURL
        viewModel.cornerLogoImage = oldImage
        viewModel.cornerLogoLoadPhase = .ready(activeURL: oldURL)
        viewModel.cornerLogoImageLoader = loader.load
        var saveCount = 0
        viewModel.testHooks.saveDataDidRun = { saveCount += 1 }

        XCTAssertTrue(viewModel.setCornerLogo(url: newURL))
        await loader.waitForRequestCount(1)

        XCTAssertEqual(viewModel.cornerLogoURL, oldURL)
        XCTAssertTrue(viewModel.cornerLogoImage === oldImage)
        XCTAssertEqual(viewModel.cornerLogoLoadPhase.candidateURL, newURL)
        XCTAssertEqual(saveCount, 0)

        loader.complete(url: newURL, with: .success(newImage))
        await Task.yield()

        XCTAssertEqual(viewModel.cornerLogoURL, newURL)
        XCTAssertTrue(viewModel.cornerLogoImage === newImage)
        XCTAssertEqual(viewModel.cornerLogoLoadPhase, .ready(activeURL: newURL))
        XCTAssertEqual(saveCount, 1)
    }

    func testCandidateDecodeFailureKeepsCurrentLogoAndReportsSanitizedFailure() async throws {
        let viewModel = makeViewModel()
        let oldURL = temporaryImageURL(named: "old.png")
        let brokenURL = temporaryImageURL(named: "broken.png")
        let oldImage = NSImage(size: NSSize(width: 12, height: 12))
        let loader = CornerLogoLoaderProbe()
        viewModel.cornerLogoURL = oldURL
        viewModel.cornerLogoImage = oldImage
        viewModel.cornerLogoLoadPhase = .ready(activeURL: oldURL)
        viewModel.cornerLogoImageLoader = loader.load
        var saveCount = 0
        viewModel.testHooks.saveDataDidRun = { saveCount += 1 }

        XCTAssertTrue(viewModel.setCornerLogo(url: brokenURL))
        await loader.waitForRequestCount(1)
        loader.complete(url: brokenURL, with: .failure(.decodeFailed))
        await Task.yield()

        XCTAssertEqual(viewModel.cornerLogoURL, oldURL)
        XCTAssertTrue(viewModel.cornerLogoImage === oldImage)
        XCTAssertEqual(viewModel.cornerLogoLoadPhase, .failed(candidateURL: brokenURL, reason: .decodeFailed))
        XCTAssertFalse(viewModel.cornerLogoLoadPhase.displayText.contains(brokenURL.path))
        XCTAssertEqual(saveCount, 0)
    }

    func testStaleCandidateCompletionCannotOverwriteNewerLogoRequest() async throws {
        let viewModel = makeViewModel()
        let firstURL = temporaryImageURL(named: "first.png")
        let secondURL = temporaryImageURL(named: "second.png")
        let firstImage = NSImage(size: NSSize(width: 12, height: 12))
        let secondImage = NSImage(size: NSSize(width: 24, height: 24))
        let loader = CornerLogoLoaderProbe()
        viewModel.cornerLogoImageLoader = loader.load

        XCTAssertTrue(viewModel.setCornerLogo(url: firstURL))
        await loader.waitForRequestCount(1)
        XCTAssertTrue(viewModel.setCornerLogo(url: secondURL))
        await loader.waitForRequestCount(2)

        loader.complete(url: firstURL, with: .success(firstImage))
        await Task.yield()

        XCTAssertNil(viewModel.cornerLogoURL)
        XCTAssertNil(viewModel.cornerLogoImage)
        XCTAssertEqual(viewModel.cornerLogoLoadPhase.candidateURL, secondURL)

        loader.complete(url: secondURL, with: .success(secondImage))
        await Task.yield()

        XCTAssertEqual(viewModel.cornerLogoURL, secondURL)
        XCTAssertTrue(viewModel.cornerLogoImage === secondImage)
        XCTAssertEqual(viewModel.cornerLogoLoadPhase, .ready(activeURL: secondURL))
    }

    func testRemovingLogoDuringCandidateLoadPreventsLateCompletionFromRevivingLogo() async throws {
        let viewModel = makeViewModel()
        let url = temporaryImageURL(named: "candidate.png")
        let image = NSImage(size: NSSize(width: 12, height: 12))
        let loader = CornerLogoLoaderProbe()
        viewModel.cornerLogoImageLoader = loader.load

        XCTAssertTrue(viewModel.setCornerLogo(url: url))
        await loader.waitForRequestCount(1)
        viewModel.removeCornerLogo()

        loader.complete(url: url, with: .success(image))
        await Task.yield()

        XCTAssertNil(viewModel.cornerLogoURL)
        XCTAssertNil(viewModel.cornerLogoImage)
        XCTAssertEqual(viewModel.cornerLogoLoadPhase, .off)
    }

    func testRetryingFailedLogoCandidateRestartsDecodeAndCommitsOnSuccess() async throws {
        let viewModel = makeViewModel()
        let url = temporaryImageURL(named: "retry.png")
        let image = NSImage(size: NSSize(width: 18, height: 18))
        let loader = CornerLogoLoaderProbe()
        viewModel.cornerLogoImageLoader = loader.load

        XCTAssertTrue(viewModel.setCornerLogo(url: url))
        await loader.waitForRequestCount(1)
        loader.complete(url: url, with: .failure(.decodeFailed))
        await waitForLogoFailure(viewModel)

        viewModel.retryCornerLogoLoad()
        await loader.waitForRequestCount(2)
        loader.complete(url: url, with: .success(image))
        await Task.yield()

        XCTAssertEqual(viewModel.cornerLogoURL, url)
        XCTAssertTrue(viewModel.cornerLogoImage === image)
        XCTAssertEqual(viewModel.cornerLogoLoadPhase, .ready(activeURL: url))
    }

    func testOutputDisplayStateDoesNotCarryCornerLogoURL() throws {
        let source = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Models/OutputDisplayState.swift")

        XCTAssertFalse(source.contains("cornerLogoURL"))
    }

    private func makeViewModel() -> SwitcherViewModel {
        let suiteName = "CornerLogoReadinessTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            userDefaults: defaults
        )
    }

    private func temporaryImageURL(named fileName: String) -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LiveSwitcherCornerLogoReadinessTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(fileName)
        let image = NSImage(size: NSSize(width: 8, height: 8))
        image.lockFocus()
        NSColor.systemBlue.setFill()
        NSRect(x: 0, y: 0, width: 8, height: 8).fill()
        image.unlockFocus()
        let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
        try? bitmap.representation(using: .png, properties: [:])?.write(to: url)
        return url
    }

    private func waitForLogoFailure(_ viewModel: SwitcherViewModel) async {
        for _ in 0..<100 {
            if case .failed = viewModel.cornerLogoLoadPhase {
                return
            }
            await Task.yield()
        }
        XCTFail("Corner logo did not fail")
    }
}

@MainActor
private final class CornerLogoLoaderProbe {
    private struct QueuedResult {
        let url: URL
        let result: Result<NSImage, CornerLogoLoadFailure>
    }

    private var requestedURLs: [URL] = []
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
