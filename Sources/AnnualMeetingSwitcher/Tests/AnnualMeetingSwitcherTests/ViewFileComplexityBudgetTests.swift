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
        let manifest = try repoText("docs/architecture/complexity-allowlist.tsv")

        XCTAssertTrue(script.contains("allow_over_budget_reason()"))
        XCTAssertTrue(manifest.contains("split planned separately"))
        XCTAssertFalse(script.contains("return 0 # allow"))
    }

    func testComplexityBudgetReadsAuditableAllowlistManifest() throws {
        let script = try repoText("script/check_complexity_budget.sh")
        let manifest = try repoText("docs/architecture/complexity-allowlist.tsv")
        let rows = manifest.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)

        XCTAssertTrue(script.contains("complexity-allowlist.tsv"))
        XCTAssertFalse(script.contains("<<'ALLOWLIST'"))
        XCTAssertEqual(rows.first, "category\tpath\tlimit\tactual\treason\ttarget_version\towner")

        let validCategories: Set<String> = [
            "top-level-view",
            "focused-subview",
            "model-reducer",
            "test-helper",
            "test-file",
            "source-contains"
        ]

        for row in rows.dropFirst() {
            let columns = row.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            XCTAssertEqual(columns.count, 7, row)
            XCTAssertTrue(validCategories.contains(columns[0]), row)
            XCTAssertTrue(FileManager.default.fileExists(atPath: try repoURL(columns[1]).path), row)
            XCTAssertFalse(columns[2].isEmpty, row)
            XCTAssertFalse(columns[3].isEmpty, row)
            XCTAssertFalse(columns[4].isEmpty, row)
            XCTAssertFalse(columns[5].isEmpty, row)
            XCTAssertFalse(columns[6].isEmpty, row)
        }
    }

    func testComplexityBudgetClassifiesViewDirectoriesRecursively() throws {
        let script = try repoText("script/check_complexity_budget.sh")

        XCTAssertTrue(script.contains("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/*/*.swift"))
        XCTAssertTrue(script.contains("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/*/*/*.swift"))
        XCTAssertFalse(script.contains("Views/ProgramMonitor/*.swift"))
        XCTAssertFalse(script.contains("Views/ProgramQueue/*.swift"))
    }

    func testComplexityBudgetDocumentationDefinesPostStableDebtPolicy() throws {
        let policy = try repoText("docs/architecture/complexity-budget.md")

        XCTAssertTrue(policy.contains("Views/**/*.swift"))
        XCTAssertTrue(policy.contains("complexity-allowlist.tsv"))
        XCTAssertTrue(policy.contains("target_version"))
        XCTAssertTrue(policy.contains("owner"))
        XCTAssertTrue(policy.contains("behavior changes: none"))
    }

    func testComplexityBudgetDocumentationRecordsLatestBurnDownSnapshot() throws {
        let policy = try repoText("docs/architecture/complexity-budget.md")

        XCTAssertTrue(policy.contains("Post-v0.5.0 Burn-Down Snapshot - 2026-06-28"))
        XCTAssertTrue(policy.contains("Allowlist rows: 21"))
        XCTAssertTrue(policy.contains("Source-string allowlist rows: 18"))
        XCTAssertTrue(policy.contains("Source-string actual total: 448"))
        XCTAssertTrue(policy.contains("No release is triggered by this allowlist burn-down"))
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
