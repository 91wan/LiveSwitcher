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

    private func workflowURL() throws -> URL {
        var directory = URL(fileURLWithPath: #filePath)
        while directory.pathComponents.count > 1 {
            directory.deleteLastPathComponent()
            let candidate = directory
                .appendingPathComponent(".github/workflows/smoke-tests.yml")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        throw XCTSkip("Could not locate smoke-tests.yml from test source path.")
    }
}
