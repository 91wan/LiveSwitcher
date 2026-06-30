import XCTest
@testable import LiveSwitcher

final class V060ReleaseReadinessTests: XCTestCase {
    func testV060VersionAndReadmeReleaseReferencesArePrepared() throws {
        XCTAssertEqual(try repositorySource("VERSION").trimmingCharacters(in: .whitespacesAndNewlines), "0.6.0")
        XCTAssertEqual(AppConfiguration.appVersion, "0.6.0")

        let english = try repositorySource("README.md")
        let chinese = try repositorySource("README_ZH.md")

        for document in [english, chinese] {
            XCTAssertTrue(document.contains("LiveSwitcher-macOS-v0.6.0.zip"))
            XCTAssertTrue(document.contains("LiveSwitcher-macOS-v0.6.0.zip.sha256"))
            XCTAssertTrue(document.contains("docs/assets/readme/live-console-v0.6.0.png"))
            XCTAssertTrue(document.contains("docs/qa/release-hygiene-v0.6.0.md"))
            XCTAssertTrue(document.contains("docs/qa/workspace-guard-v0.6.0.md"))
        }
    }

    func testV060ReleaseReadinessDocumentLocksDraftAndApprovalGates() throws {
        let document = try repositorySource("docs/qa/release-readiness-v0.6.0.md")

        XCTAssertTrue(document.contains("# LiveSwitcher v0.6.0 Release Readiness"))
        XCTAssertTrue(document.localizedStandardContains("Draft PR"))
        XCTAssertTrue(document.localizedStandardContains("do not tag"))
        XCTAssertTrue(document.localizedStandardContains("do not create a GitHub Release"))
        XCTAssertTrue(document.localizedStandardContains("explicit user approval"))
        XCTAssertTrue(document.localizedStandardContains("hardware rehearsal PASS"))
        XCTAssertTrue(document.localizedStandardContains("security checklist PASS"))
        XCTAssertTrue(document.localizedStandardContains("support/log privacy checklist PASS"))
        XCTAssertTrue(document.localizedStandardContains("release-candidate build/hash evidence"))
        XCTAssertTrue(document.localizedStandardContains("phone-lan-remote-hardware-results-v0.6.0.md"))
        XCTAssertTrue(document.localizedStandardContains("Final phone UI smoke after #448 / #450"))
        XCTAssertTrue(document.localizedStandardContains("final-phone-ui-smoke-after-448--450"))
        XCTAssertTrue(document.localizedStandardContains("PR #454"))
        XCTAssertTrue(document.localizedStandardContains("excluded from v0.6.0"))
        XCTAssertTrue(document.localizedStandardContains("Android Chrome"))
        XCTAssertTrue(document.localizedStandardContains("BLOCKED as unavailable"))

        XCTAssertFalse(document.localizedStandardContains("Published at"))
        XCTAssertFalse(document.localizedStandardContains("https://github.com/91wan/LiveSwitcher/releases/tag/v0.6.0"))
        XCTAssertFalse(document.localizedStandardContains("Draft | `false`"))
    }

    func testV060RemotePolishScopeIncludesIssues448And450ButExcludes449() throws {
        let english = try repositorySource("README.md")
        let chinese = try repositorySource("README_ZH.md")
        let readiness = try repositorySource("docs/qa/release-readiness-v0.6.0.md")
        let hygiene = try repositorySource("docs/qa/release-hygiene-v0.6.0.md")

        XCTAssertTrue(english.localizedStandardContains("action-specific command feedback"))
        XCTAssertTrue(english.localizedStandardContains("media/program controls share one visual role"))
        XCTAssertTrue(english.localizedStandardContains("Previous Item remote command remains outside v0.6.0"))

        XCTAssertTrue(chinese.localizedStandardContains("具体命令反馈"))
        XCTAssertTrue(chinese.localizedStandardContains("媒体/节目控件统一视觉角色"))
        XCTAssertTrue(chinese.localizedStandardContains("切上一项"))
        XCTAssertTrue(chinese.localizedStandardContains("不包含在 v0.6.0"))

        for document in [readiness, hygiene] {
            XCTAssertTrue(document.localizedStandardContains("Issue #448"))
            XCTAssertTrue(document.localizedStandardContains("Issue #450"))
            XCTAssertTrue(document.localizedStandardContains("Issue #449"))
            XCTAssertTrue(document.localizedStandardContains("action-specific command feedback"))
            XCTAssertTrue(document.localizedStandardContains("program/media color roles"))
            XCTAssertTrue(document.localizedStandardContains("Previous Item remains out of scope"))
        }
    }

    func testV060ReleaseHygieneAndWorkspaceGuardDocumentsExist() throws {
        let hygiene = try repositorySource("docs/qa/release-hygiene-v0.6.0.md")
        let guardDoc = try repositorySource("docs/qa/workspace-guard-v0.6.0.md")

        XCTAssertTrue(hygiene.contains("# LiveSwitcher v0.6.0"))
        XCTAssertTrue(hygiene.localizedStandardContains("phone LAN remote"))
        XCTAssertTrue(hygiene.localizedStandardContains("source-available, ad-hoc signed, and not notarized"))
        XCTAssertTrue(hygiene.localizedStandardContains("tag/main equality"))
        XCTAssertTrue(hygiene.localizedStandardContains("draft release"))
        XCTAssertTrue(hygiene.localizedStandardContains("explicit user approval"))
        XCTAssertTrue(hygiene.localizedStandardContains("no release or tag is created by this readiness PR"))

        XCTAssertTrue(guardDoc.contains("# LiveSwitcher v0.6.0 Workspace Guard"))
        XCTAssertTrue(guardDoc.localizedStandardContains("clean `main` checkout"))
        XCTAssertTrue(guardDoc.localizedStandardContains("VERSION must equal the tag name"))
        XCTAssertTrue(guardDoc.localizedStandardContains("LiveSwitcher-macOS-v0.6.0.zip"))
    }
}
