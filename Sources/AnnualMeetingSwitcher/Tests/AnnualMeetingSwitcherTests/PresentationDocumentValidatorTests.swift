import Foundation
import XCTest
@testable import LiveSwitcher

final class PresentationDocumentValidatorTests: XCTestCase {
    func testPowerPointMustBeAReadableNonEmptyFileNotADirectory() throws {
        let validPPTX = try makeTempFileURL(ext: "pptx", contents: Data("pptx".utf8))
        let emptyPPTX = try makeTempFileURL(ext: "pptx", contents: Data())
        let directoryPPTX = try makeTempDirectoryURL(ext: "pptx")
        defer {
            try? FileManager.default.removeItem(at: validPPTX)
            try? FileManager.default.removeItem(at: emptyPPTX)
            try? FileManager.default.removeItem(at: directoryPPTX)
        }

        XCTAssertTrue(PresentationDocumentValidator.isLikelyValid(url: validPPTX, sourceKind: .pptx))
        XCTAssertFalse(PresentationDocumentValidator.isLikelyValid(url: emptyPPTX, sourceKind: .pptx))
        XCTAssertFalse(PresentationDocumentValidator.isLikelyValid(url: directoryPPTX, sourceKind: .pptx))
    }

    func testKeynoteAllowsPackageDirectoriesAndNonEmptyFiles() throws {
        let keynotePackage = try makeTempDirectoryURL(ext: "keynote")
        let emptyKeynotePackage = try makeTempDirectoryURL(ext: "keynote")
        let keynoteFile = try makeTempFileURL(ext: "key", contents: Data("key".utf8))
        let emptyKeynoteFile = try makeTempFileURL(ext: "key", contents: Data())
        FileManager.default.createFile(
            atPath: keynotePackage.appendingPathComponent("index.zip").path,
            contents: Data("package".utf8)
        )
        defer {
            try? FileManager.default.removeItem(at: keynotePackage)
            try? FileManager.default.removeItem(at: emptyKeynotePackage)
            try? FileManager.default.removeItem(at: keynoteFile)
            try? FileManager.default.removeItem(at: emptyKeynoteFile)
        }

        XCTAssertTrue(PresentationDocumentValidator.isLikelyValid(url: keynotePackage, sourceKind: .keynote))
        XCTAssertTrue(PresentationDocumentValidator.isLikelyValid(url: keynoteFile, sourceKind: .keynote))
        XCTAssertFalse(PresentationDocumentValidator.isLikelyValid(url: emptyKeynotePackage, sourceKind: .keynote))
        XCTAssertFalse(PresentationDocumentValidator.isLikelyValid(url: emptyKeynoteFile, sourceKind: .keynote))
    }

    func testNonPresentationKindsAreNeverValidDeckDocuments() throws {
        let media = try makeTempFileURL(ext: "mp4", contents: Data("video".utf8))
        defer { try? FileManager.default.removeItem(at: media) }

        XCTAssertFalse(PresentationDocumentValidator.isLikelyValid(url: media, sourceKind: .media))
        XCTAssertFalse(PresentationDocumentValidator.isLikelyValid(url: media, sourceKind: .html))
        XCTAssertFalse(PresentationDocumentValidator.isLikelyValid(url: media, sourceKind: .activeDeck))
        XCTAssertFalse(PresentationDocumentValidator.isLikelyValid(url: media, sourceKind: .agendaMarker))
        XCTAssertFalse(PresentationDocumentValidator.isLikelyValid(url: media, sourceKind: .unsupported))
    }

    private func makeTempFileURL(ext: String, contents: Data) throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)
        FileManager.default.createFile(atPath: url.path, contents: contents)
        return url
    }

    private func makeTempDirectoryURL(ext: String) throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        return url
    }
}
