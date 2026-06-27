import XCTest
@testable import LiveSwitcher

final class ProductSurfaceGateTests: XCTestCase {
    func testProductSurfaceGateDocumentsRequiredReviewQuestions() throws {
        let document = try productSurfaceGateText()
        let requiredQuestions = [
            "1. Is this live execution or setup configuration?",
            "2. Does this enter Live Mode?",
            "3. If it enters Live Mode, which existing action does it replace?",
            "4. Does it increase accidental-trigger risk?",
            "5. Does it require external display hardware acceptance?",
            "6. Who owns the Runtime state?",
            "7. Could support reports leak customer content?",
            "8. Is there a chance to delete or merge an existing control?"
        ]

        for question in requiredQuestions {
            XCTAssertTrue(document.contains(question), "Missing gate question: \(question)")
        }
    }

    func testProductSurfaceGateStaysInSyncWithLiveModePolicy() throws {
        let document = try productSurfaceGateText()

        XCTAssertEqual(Set(LiveModeSimplicityPolicy.allowedActions), Set(LiveModeActionKind.allCases))
        for action in LiveModeSimplicityPolicy.allowedActions {
            XCTAssertTrue(document.contains(action.rawValue), "Missing allowed action token: \(action.rawValue)")
            XCTAssertTrue(document.localizedStandardContains(action.documentationLabel), "Missing allowed action label: \(action.documentationLabel)")
        }

        XCTAssertEqual(Set(LiveModeSimplicityPolicy.forbiddenConfigurationSurfaces), Set(LiveModeConfigurationSurface.allCases))
        for surface in LiveModeSimplicityPolicy.forbiddenConfigurationSurfaces {
            XCTAssertTrue(document.contains(surface.rawValue), "Missing forbidden surface token: \(surface.rawValue)")
            XCTAssertTrue(document.localizedStandardContains(surface.documentationLabel), "Missing forbidden surface label: \(surface.documentationLabel)")
        }
    }

    func testProductSurfaceGateKeepsNewLiveControlsDefaultDenied() throws {
        let document = try productSurfaceGateText()

        XCTAssertTrue(document.contains("New Live Mode controls are default-denied."))
        XCTAssertTrue(document.contains("prove that the control reduces operator accidents"))
        XCTAssertTrue(document.contains("update LiveModeSimplicityPolicy"))
        XCTAssertTrue(document.contains("visible-behavior tests"))
        XCTAssertTrue(document.contains("external display hardware acceptance"))
    }

    private func productSurfaceGateText() throws -> String {
        try repositoryText("docs/architecture/product-surface-gate.md")
    }

    private func repositoryText(_ relativePath: String) throws -> String {
        try String(contentsOf: repositoryRoot().appendingPathComponent(relativePath), encoding: .utf8)
    }

    private func repositoryRoot() throws -> URL {
        var directory = URL(fileURLWithPath: #filePath)
        while directory.pathComponents.count > 1 {
            directory.deleteLastPathComponent()
            let candidate = directory.appendingPathComponent("docs")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return directory
            }
        }
        throw XCTSkip("Could not locate repository root from test source path.")
    }
}
