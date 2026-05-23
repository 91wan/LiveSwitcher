import XCTest

final class CISmokeWorkflowTests: XCTestCase {
    func testSmokeWorkflowRunsReleaseHygieneFallbackAndPackageChecks() throws {
        let workflow = try String(contentsOf: workflowURL(), encoding: .utf8)

        XCTAssertTrue(workflow.contains("Release Hygiene Fallback PATH"))
        XCTAssertTrue(workflow.contains("PATH=/usr/bin:/bin:/usr/sbin:/sbin ./script/check_release_hygiene.sh"))
        XCTAssertTrue(workflow.contains("bash Sources/AnnualMeetingSwitcher/build_v33.sh"))
        XCTAssertTrue(workflow.contains("plutil -lint dist/LiveSwitcher.app/Contents/Info.plist"))
        XCTAssertTrue(workflow.contains("codesign --verify --deep --strict dist/LiveSwitcher.app"))
    }

    func testWorkflowsUseNode24CompatibleCheckoutAction() throws {
        let smokeWorkflow = try String(contentsOf: workflowURL(), encoding: .utf8)
        let releaseWorkflow = try String(contentsOf: workflowURL(named: "release.yml"), encoding: .utf8)

        XCTAssertTrue(smokeWorkflow.contains("uses: actions/checkout@v6"))
        XCTAssertTrue(releaseWorkflow.contains("uses: actions/checkout@v6"))
        XCTAssertFalse(smokeWorkflow.contains("uses: actions/checkout@v4"))
        XCTAssertFalse(releaseWorkflow.contains("uses: actions/checkout@v4"))
    }

    private func workflowURL() throws -> URL {
        try workflowURL(named: "smoke-tests.yml")
    }

    private func workflowURL(named filename: String) throws -> URL {
        var directory = URL(fileURLWithPath: #filePath)
        while directory.pathComponents.count > 1 {
            directory.deleteLastPathComponent()
            let candidate = directory
                .appendingPathComponent(".github/workflows")
                .appendingPathComponent(filename)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        throw XCTSkip("Could not locate \(filename) from test source path.")
    }
}
