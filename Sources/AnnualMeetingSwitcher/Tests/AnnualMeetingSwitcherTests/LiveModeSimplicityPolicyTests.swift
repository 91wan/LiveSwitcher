import XCTest
@testable import LiveSwitcher

final class LiveModeSimplicityPolicyTests: XCTestCase {
    func testAllowedLiveActionsAreExplicit() {
        XCTAssertEqual(
            Set(LiveModeSimplicityPolicy.allowedActions),
            Set(LiveModeActionKind.allCases)
        )
        XCTAssertTrue(LiveModeSimplicityPolicy.isAllowed(.switchSource))
        XCTAssertTrue(LiveModeSimplicityPolicy.isAllowed(.toggleProjection))
        XCTAssertTrue(LiveModeSimplicityPolicy.isAllowed(.togglePanic))
    }

    func testForbiddenConfigurationSurfacesAreExplicit() {
        XCTAssertEqual(
            Set(LiveModeSimplicityPolicy.forbiddenConfigurationSurfaces),
            Set(LiveModeConfigurationSurface.allCases)
        )
        XCTAssertTrue(LiveModeSimplicityPolicy.isForbidden(.importProgramSource))
        XCTAssertTrue(LiveModeSimplicityPolicy.isForbidden(.editBGMLibrary))
        XCTAssertTrue(LiveModeSimplicityPolicy.isForbidden(.editAutomationSettings))
    }

    func testPrimaryActionLimitIsSmall() {
        XCTAssertLessThanOrEqual(LiveModeSimplicityPolicy.maxPrimaryActionCount, 12)
        XCTAssertLessThanOrEqual(LiveModeSimplicityPolicy.primaryActions.count, LiveModeSimplicityPolicy.maxPrimaryActionCount)
        XCTAssertLessThanOrEqual(LiveModeSimplicityPolicy.maxLiveRailCardCount, 4)
        XCTAssertLessThanOrEqual(LiveModeSimplicityPolicy.maxVisibleBGMRows, 5)
        XCTAssertTrue(Set(LiveModeSimplicityPolicy.primaryActions).isSubset(of: Set(LiveModeSimplicityPolicy.allowedActions)))
    }

    func testEveryAllowedActionIsDocumented() throws {
        let document = try repositoryText("docs/architecture/live-mode-simplicity-rules.md")

        for action in LiveModeActionKind.allCases {
            XCTAssertTrue(
                document.localizedStandardContains(action.documentationLabel),
                "Missing allowed live action documentation for \(action.rawValue)"
            )
        }
    }

    func testEveryForbiddenSurfaceIsDocumented() throws {
        let document = try repositoryText("docs/architecture/live-mode-simplicity-rules.md")

        for surface in LiveModeConfigurationSurface.allCases {
            XCTAssertTrue(
                document.localizedStandardContains(surface.documentationLabel),
                "Missing forbidden configuration surface documentation for \(surface.rawValue)"
            )
        }
    }

    func testNoForbiddenConfigurationSurfaceCanBeAllowed() {
        let actionRawValues = Set(LiveModeActionKind.allCases.map(\.rawValue))

        for surface in LiveModeConfigurationSurface.allCases {
            XCTAssertFalse(actionRawValues.contains(surface.rawValue))
            XCTAssertTrue(LiveModeSimplicityPolicy.isForbidden(surface))
        }
    }

    func testNewLiveActionRequiresPolicyAndDocumentation() throws {
        let document = try repositoryText("docs/architecture/live-mode-simplicity-rules.md")

        XCTAssertEqual(Set(LiveModeSimplicityPolicy.allowedActions), Set(LiveModeActionKind.allCases))
        for action in LiveModeSimplicityPolicy.allowedActions {
            XCTAssertTrue(
                document.localizedStandardContains(action.documentationLabel),
                "Missing documentation for allowed live action \(action.rawValue)"
            )
        }
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
