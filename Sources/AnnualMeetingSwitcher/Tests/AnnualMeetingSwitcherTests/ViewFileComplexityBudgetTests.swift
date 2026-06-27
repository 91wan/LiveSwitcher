import XCTest

final class ViewFileComplexityBudgetTests: XCTestCase {
    func testWorkspaceGuardRunsComplexityBudgetGate() throws {
        let guardScript = try repoText("script/check_workspace_guard.sh")

        XCTAssertTrue(guardScript.contains("script/check_complexity_budget.sh \"$MODE\""))
    }

    func testComplexityBudgetScriptDefinesPostStableBudgets() throws {
        let script = try repoText("script/check_complexity_budget.sh")

        XCTAssertTrue(script.contains("MAX_TOP_LEVEL_VIEW_LINES=300"))
        XCTAssertTrue(script.contains("MAX_FOCUSED_SUBVIEW_LINES=250"))
        XCTAssertTrue(script.contains("MAX_MODEL_REDUCER_LINES=400"))
        XCTAssertTrue(script.contains("MAX_TEST_HELPER_LINES=250"))
        XCTAssertTrue(script.contains("MAX_TEST_FILE_LINES=500"))
        XCTAssertTrue(script.contains("MAX_SOURCE_CONTAINS_PER_TEST_FILE=15"))
        XCTAssertTrue(script.contains("git ls-files"))
        XCTAssertTrue(script.contains("source_contains_count"))
    }

    func testComplexityBudgetAllowlistEntriesCarryReasons() throws {
        let script = try repoText("script/check_complexity_budget.sh")

        XCTAssertTrue(script.contains("allow_over_budget_reason()"))
        XCTAssertTrue(script.contains("split planned separately"))
        XCTAssertFalse(script.contains("return 0 # allow"))
    }

    private func repoText(_ relativePath: String) throws -> String {
        try String(contentsOf: repoURL(relativePath), encoding: .utf8)
    }

    private func repoURL(_ relativePath: String) throws -> URL {
        try repoRoot().appendingPathComponent(relativePath)
    }

    private func repoRoot() throws -> URL {
        var directory = URL(fileURLWithPath: #filePath)
        while directory.pathComponents.count > 1 {
            directory.deleteLastPathComponent()
            let marker = directory.appendingPathComponent("Package.swift")
            let scriptDir = directory.appendingPathComponent("script")
            if FileManager.default.fileExists(atPath: marker.path),
               FileManager.default.fileExists(atPath: scriptDir.path) {
                return directory
            }
        }
        throw XCTSkip("Could not locate repository root from test source path.")
    }
}
