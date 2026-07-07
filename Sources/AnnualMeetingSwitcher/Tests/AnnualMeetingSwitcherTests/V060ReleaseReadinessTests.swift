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
            XCTAssertTrue(document.contains("docs/qa/release-approval-package-v0.6.0.md"))
            XCTAssertTrue(document.contains("docs/qa/release-publication-audit-v0.6.0.md"))
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
        XCTAssertTrue(document.localizedStandardContains("release-approval-package-v0.6.0.md"))
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
        XCTAssertTrue(hygiene.localizedStandardContains("tag/publication-target equality"))
        XCTAssertTrue(hygiene.localizedStandardContains("released-complete"))
        XCTAssertTrue(hygiene.localizedStandardContains("GitHub Release is published"))
        XCTAssertTrue(hygiene.localizedStandardContains("LiveSwitcher-macOS-v0.6.0.zip: OK"))
        XCTAssertTrue(hygiene.localizedStandardContains("release-publication-audit-v0.6.0.md"))

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

    func testV060FinalApprovalPackageCollectsReleaseDecisionInputs() throws {
        let document = try repositorySource("docs/qa/release-approval-package-v0.6.0.md")
        let hygiene = try repositorySource("docs/qa/release-hygiene-v0.6.0.md")

        XCTAssertTrue(document.contains("# LiveSwitcher v0.6.0 Final Approval Package"))
        XCTAssertTrue(document.contains("Candidate source SHA | `faf664680800171cf48181063a4510a5e119b06e`"))
        XCTAssertTrue(document.contains("Artifact audit SHA | `cf8c607e7ee31deeb0016a47106f3ccc6a12b878`"))
        XCTAssertTrue(document.contains("Publication target SHA | `1498da8d11777cd4e52ce0740dc52d47ca602bb3`"))
        XCTAssertTrue(document.localizedStandardContains("released-complete"))
        XCTAssertTrue(document.localizedStandardContains("GitHub Release is published"))
        XCTAssertTrue(document.localizedStandardContains("https://github.com/91wan/LiveSwitcher/releases/tag/v0.6.0"))
        XCTAssertTrue(document.localizedStandardContains("release notes"))
        XCTAssertTrue(document.localizedStandardContains("Final phone UI smoke after #448 / #450"))
        XCTAssertTrue(document.localizedStandardContains("final-phone-ui-smoke-after-448--450"))
        XCTAssertTrue(document.localizedStandardContains("phone-lan-remote-hardware-results-v0.6.0.md"))
        XCTAssertTrue(document.localizedStandardContains("release-artifact-audit-v0.6.0.md"))
        XCTAssertTrue(document.localizedStandardContains("release-publication-audit-v0.6.0.md"))
        XCTAssertTrue(document.localizedStandardContains("Android Chrome"))
        XCTAssertTrue(document.localizedStandardContains("Unverified"))
        XCTAssertTrue(document.localizedStandardContains("Issue #449"))
        XCTAssertTrue(document.localizedStandardContains("not part of v0.6.0"))
        XCTAssertTrue(document.localizedStandardContains("PR #454"))
        XCTAssertTrue(document.localizedStandardContains("explicitly excluded"))
        XCTAssertTrue(document.contains("079865e39ccef8fe711e8c8a34a0d0813288aecf19a66394392533182a9e5ad2"))
        XCTAssertTrue(document.localizedStandardContains("LiveSwitcher-macOS-v0.6.0.zip: OK"))
        XCTAssertTrue(document.localizedStandardContains("批准发布 v0.6.0"))
        XCTAssertTrue(hygiene.localizedStandardContains("release-approval-package-v0.6.0.md"))
        XCTAssertTrue(hygiene.localizedStandardContains("released-complete"))

        XCTAssertFalse(document.localizedStandardContains("TBD after the release stack is merged to origin/main"))
        XCTAssertFalse(document.localizedStandardContains("No automatic publication"))
        XCTAssertFalse(document.contains("6e0adf68b80b19adae3ef56020b07c100f4088e0"))
        XCTAssertFalse(document.contains("113132a9b9aab3e96a37e6bd7249dce4a87c6dad"))
        XCTAssertFalse(document.contains("166bbbe41f901c5796d72878f8963a2b55d50f8a13097b3b2915c4a3768a9a3f"))
        XCTAssertFalse(document.contains("b3f7271e6ff30952817b759e415e88bc12272d6672d9691dbe3f484e53a28e50"))
    }

    func testV060PublicationAuditRecordsReleasedCompleteState() throws {
        let document = try repositorySource("docs/qa/release-publication-audit-v0.6.0.md")

        XCTAssertTrue(document.contains("# LiveSwitcher v0.6.0 Publication State Audit"))
        XCTAssertTrue(document.contains("Publication target SHA | `1498da8d11777cd4e52ce0740dc52d47ca602bb3`"))
        XCTAssertTrue(document.contains("v0.6.0 tag SHA | `1498da8d11777cd4e52ce0740dc52d47ca602bb3`"))
        XCTAssertTrue(document.localizedStandardContains("tag == publication target | PASS"))
        XCTAssertTrue(document.localizedStandardContains("Audit PR base SHA | `1498da8d11777cd4e52ce0740dc52d47ca602bb3`"))
        XCTAssertTrue(document.localizedStandardContains("post-publication docs/tests evidence"))
        XCTAssertTrue(document.localizedStandardContains("not part of the v0.6.0 released artifact"))
        XCTAssertTrue(document.localizedStandardContains("Use PR #456 metadata for review-head identity"))
        XCTAssertTrue(document.localizedStandardContains("Release state | released-complete"))
        XCTAssertTrue(document.localizedStandardContains("GitHub Release exists | yes"))
        XCTAssertTrue(document.localizedStandardContains("Release draft | no"))
        XCTAssertTrue(document.localizedStandardContains("Release prerelease | no"))
        XCTAssertTrue(document.localizedStandardContains("https://github.com/91wan/LiveSwitcher/releases/tag/v0.6.0"))
        XCTAssertTrue(document.localizedStandardContains("LiveSwitcher-macOS-v0.6.0.zip"))
        XCTAssertTrue(document.localizedStandardContains("LiveSwitcher-macOS-v0.6.0.zip.sha256"))
        XCTAssertTrue(document.contains("079865e39ccef8fe711e8c8a34a0d0813288aecf19a66394392533182a9e5ad2"))
        XCTAssertTrue(document.localizedStandardContains("Zip checksum verification | PASS"))
        XCTAssertTrue(document.localizedStandardContains("LiveSwitcher-macOS-v0.6.0.zip: OK"))
        XCTAssertTrue(document.localizedStandardContains("Codesign verification | PASS"))
        XCTAssertTrue(document.contains("6d4b4e65f4ae6530801f8e12af6a7dcfb9b8365c58145570838b318d400f4b23"))
        XCTAssertTrue(document.contains("8701619d0a3ce827cd6e3a200ab660aff6d87ff273d2a15ee60ec72e62099c06"))
        XCTAssertTrue(document.localizedStandardContains("CFBundleShortVersionString | `0.6.0`"))
        XCTAssertTrue(document.localizedStandardContains("CFBundleIdentifier | `com.91wan.liveswitcher`"))
        XCTAssertTrue(document.localizedStandardContains("LSMinimumSystemVersion | `14.0`"))
        XCTAssertTrue(document.localizedStandardContains("PR #454"))
        XCTAssertTrue(document.localizedStandardContains("excluded from v0.6.0"))
        XCTAssertTrue(document.localizedStandardContains("Issue #449"))
        XCTAssertTrue(document.localizedStandardContains("backlog"))
        XCTAssertTrue(document.localizedStandardContains("Next action | No release action required"))
        XCTAssertFalse(document.localizedStandardContains("Main SHA | `1498da8d11777cd4e52ce0740dc52d47ca602bb3`"))
        XCTAssertFalse(document.localizedStandardContains("tag == main | PASS"))
        XCTAssertFalse(document.localizedStandardContains("origin/main / v0.6.0"))
        XCTAssertFalse(document.localizedStandardContains("Audit PR head SHA"))
        XCTAssertFalse(document.contains("5f2d3d472561f7e61063f44476e9b70bac9b610e"))
        XCTAssertFalse(document.contains("6034d1e7c9e6609d898dc00cb87a3c59d5ad9112"))
    }
}
