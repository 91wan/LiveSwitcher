import AppKit
import XCTest
@testable import LiveSwitcher

final class ThumbnailServiceTests: XCTestCase {
    func testDefaultCacheDirectoryLivesInLiveSwitcherThumbnailCache() {
        let path = ThumbnailService.defaultCacheDirectory.path

        XCTAssertTrue(path.contains("/Caches/"))
        XCTAssertTrue(path.hasSuffix("LiveSwitcher/thumbnails"))
    }

    func testCacheKeyChangesWhenFileModificationDateChanges() {
        let url = URL(fileURLWithPath: "/tmp/Opening Final.mp4")
        let size = CGSize(width: 96, height: 54)
        let first = ThumbnailService.cacheKey(
            for: url,
            kind: .media,
            targetSize: size,
            modificationDate: Date(timeIntervalSince1970: 1_000)
        )
        let second = ThumbnailService.cacheKey(
            for: url,
            kind: .media,
            targetSize: size,
            modificationDate: Date(timeIntervalSince1970: 2_000)
        )

        XCTAssertNotEqual(first, second)
        XCTAssertTrue(first.hasSuffix(".png"))
    }

    func testFallbackSymbolsAreDefinedForProgramSourceKinds() {
        XCTAssertEqual(ThumbnailService.fallbackSystemImage(for: .media, isVideo: true), "film")
        XCTAssertEqual(ThumbnailService.fallbackSystemImage(for: .media, isVideo: false), "music.note")
        XCTAssertEqual(ThumbnailService.fallbackSystemImage(for: .html, isVideo: false), "globe")
        XCTAssertEqual(ThumbnailService.fallbackSystemImage(for: .pptx, isVideo: false), "doc.richtext")
        XCTAssertEqual(ThumbnailService.fallbackSystemImage(for: .keynote, isVideo: false), "play.rectangle.fill")
        XCTAssertEqual(ThumbnailService.fallbackSystemImage(for: .activeDeck, isVideo: false), "play.rectangle.fill")
        XCTAssertEqual(ThumbnailService.fallbackSystemImage(for: .unsupported, isVideo: false), "doc.fill")
    }

    func testAudioProgramThumbnailUsesCacheAndInvalidatesOnMTimeChange() async throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("LiveSwitcherThumbnailTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let audio = temp.appendingPathComponent("walk-in.mp3")
        try Data("not-real-audio-but-enough-for-placeholder".utf8).write(to: audio)
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSince1970: 1_000)],
            ofItemAtPath: audio.path
        )

        let service = ThumbnailService(cacheDirectory: temp.appendingPathComponent("thumbs", isDirectory: true))
        let size = CGSize(width: 96, height: 54)
        let firstURL = try await service.cacheFileURL(for: audio, kind: .media, targetSize: size)
        let first = await service.thumbnail(for: audio, kind: .media, targetSize: size)

        XCTAssertNotNil(first)
        XCTAssertTrue(FileManager.default.fileExists(atPath: firstURL.path))

        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSince1970: 2_000)],
            ofItemAtPath: audio.path
        )
        let secondURL = try await service.cacheFileURL(for: audio, kind: .media, targetSize: size)

        XCTAssertNotEqual(firstURL.lastPathComponent, secondURL.lastPathComponent)
    }

    func testRunQueueRowsRenderThumbnailViewInsteadOfPlainIconOnlySourceRows() throws {
        let source = try sourceText("Views/RunQueueView.swift")

        XCTAssertTrue(source.contains("ProgramThumbnailView("))
        XCTAssertTrue(source.contains("displaySize: CGSize(width: 48, height: 27)"))
        XCTAssertTrue(source.contains("private let rowContentIndent"))
    }

    private func sourceText(_ relativePath: String) throws -> String {
        let candidate = try sourceRoot().appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: candidate.path) else {
            throw XCTSkip("Could not locate \(relativePath)")
        }
        return try String(contentsOf: candidate, encoding: .utf8)
    }

    private func sourceRoot() throws -> URL {
        var directory = URL(fileURLWithPath: #filePath)
        while directory.pathComponents.count > 1 {
            directory.deleteLastPathComponent()
            let candidate = directory.appendingPathComponent("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher")
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: candidate.path, isDirectory: &isDirectory),
               isDirectory.boolValue {
                return candidate
            }
        }
        throw XCTSkip("Could not locate app source root from test path.")
    }
}
