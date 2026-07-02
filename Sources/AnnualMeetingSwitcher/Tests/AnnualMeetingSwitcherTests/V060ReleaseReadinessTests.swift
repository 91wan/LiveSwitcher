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

    func testV060ArtifactAuditRecordsRefreshedCandidateEvidence() throws {
        let document = try repositorySource("docs/qa/release-artifact-audit-v0.6.0.md")
        let hygiene = try repositorySource("docs/qa/release-hygiene-v0.6.0.md")

        XCTAssertTrue(document.contains("Candidate source SHA: `faf664680800171cf48181063a4510a5e119b06e`"))
        XCTAssertTrue(document.contains("VERSION` file value: `0.6.0`"))
        XCTAssertTrue(document.localizedStandardContains("Prior artifact hashes from source `6e0adf68b80b19adae3ef56020b07c100f4088e0`"))
        XCTAssertTrue(document.localizedStandardContains("superseded and must not be reused"))
        XCTAssertTrue(document.contains("`CFBundleShortVersionString` | `0.6.0`"))
        XCTAssertTrue(document.contains("`CFBundleIdentifier` | `com.91wan.liveswitcher`"))
        XCTAssertTrue(document.contains("`LSMinimumSystemVersion` | `14.0`"))
        XCTAssertTrue(document.contains("`CFBundleIconFile` | `AppIcon`"))
        XCTAssertTrue(document.localizedStandardContains("App launch verification | PASS"))
        XCTAssertTrue(document.contains("`dist/LiveSwitcher.app/Contents/MacOS/LiveSwitcher` | `f374be32fc7bddb7cb144350905192d179b376f05c17f6d6b825492bc54d3561`"))
        XCTAssertTrue(document.contains("`dist/LiveSwitcher.app` max-depth-3 file-list hash | `f84e3ef6556deed510f036548919421596ea5ed2e343d892422116a58532c1ec`"))
        XCTAssertTrue(document.contains("`dist/LiveSwitcher.app/Contents/Resources/AppIcon.icns` | `8701619d0a3ce827cd6e3a200ab660aff6d87ff273d2a15ee60ec72e62099c06`"))
        XCTAssertTrue(document.contains("`dist/LiveSwitcher-macOS-v0.6.0.zip` | `cf617288dd0e34bd753dfaa2c5f997f8756668c41b71de9a5e919aee1a98fbbb`"))
        XCTAssertTrue(document.localizedStandardContains("Zip checksum verification | PASS"))
        XCTAssertTrue(document.localizedStandardContains("No token values, phone IP literals, or live program-title samples were found"))
        XCTAssertTrue(hygiene.localizedStandardContains("app launch verification"))

        XCTAssertFalse(document.contains("166bbbe41f901c5796d72878f8963a2b55d50f8a13097b3b2915c4a3768a9a3f"))
        XCTAssertFalse(document.contains("b3f7271e6ff30952817b759e415e88bc12272d6672d9691dbe3f484e53a28e50"))
        XCTAssertFalse(document.contains("7db3810f509964589a4104622a91b65a56993f2e2f5007668ed5b598d2634d9f"))
    }
}
