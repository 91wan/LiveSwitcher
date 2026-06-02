import XCTest

final class BuildReleaseHygieneTests: XCTestCase {
    func testReleaseHygieneDerivesPreviousVersionAndChecksPackageManifests() throws {
        let script = try repoText("script/check_release_hygiene.sh")

        XCTAssertFalse(script.contains("PREVIOUS_VERSION=\"0."))
        XCTAssertTrue(script.contains("derive_previous_version()"))
        XCTAssertTrue(script.contains("require_package_manifest_sync()"))
        XCTAssertTrue(script.contains("release-hygiene-v*.md"))
    }

    func testReleaseHygieneFallbackIgnoresWorktreeGitPointerFile() throws {
        let script = try repoText("script/check_release_hygiene.sh")

        XCTAssertTrue(script.contains("--exclude=.git"))
        XCTAssertTrue(script.contains("--exclude-dir=.git"))
    }

    func testBuildScriptsShareTCCUsageDescriptionKeys() throws {
        let buildAndRun = try repoText("script/build_and_run.sh")
        let releaseBuild = try repoText("Sources/AnnualMeetingSwitcher/build_v33.sh")
        let requiredKeys = [
            "NSAccessibilityUsageDescription",
            "NSAppleEventsUsageDescription",
            "NSCameraUsageDescription",
            "NSMicrophoneUsageDescription"
        ]

        for key in requiredKeys {
            XCTAssertTrue(buildAndRun.contains(key), "build_and_run.sh missing \(key)")
            XCTAssertTrue(releaseBuild.contains(key), "build_v33.sh missing \(key)")
        }
    }

    func testBuildScriptsCopySwiftPMResourceBundleIntoAppBundle() throws {
        let buildAndRun = try repoText("script/build_and_run.sh")
        let releaseBuild = try repoText("Sources/AnnualMeetingSwitcher/build_v33.sh")

        for script in [buildAndRun, releaseBuild] {
            XCTAssertTrue(script.contains("LiveSwitcher_LiveSwitcher.bundle"))
            XCTAssertTrue(script.contains("cp -R \"$RESOURCE_BUNDLE\""))
            XCTAssertTrue(script.contains("Contents/Resources") || script.contains("APP_RESOURCES=\"$APP_CONTENTS/Resources\""))
        }
    }

    func testBuildScriptsDeclareSupportedBundleLocalizations() throws {
        let buildAndRun = try repoText("script/build_and_run.sh")
        let releaseBuild = try repoText("Sources/AnnualMeetingSwitcher/build_v33.sh")

        for script in [buildAndRun, releaseBuild] {
            XCTAssertTrue(script.contains("CFBundleLocalizations"))
            XCTAssertTrue(script.contains("<string>en</string>"))
            XCTAssertTrue(script.contains("<string>zh-Hans</string>"))
        }
    }

    func testPackageManifestTargetsStayAligned() throws {
        let rootPackage = try repoText("Package.swift")
        let nestedPackage = try repoText("Sources/AnnualMeetingSwitcher/Package.swift")

        for manifest in [rootPackage, nestedPackage] {
            XCTAssertTrue(manifest.contains("name: \"LiveSwitcher\""))
            XCTAssertTrue(manifest.contains(".executableTarget("))
            XCTAssertTrue(manifest.contains("name: \"LiveSwitcher\""))
            XCTAssertTrue(manifest.contains(".testTarget("))
            XCTAssertTrue(manifest.contains("name: \"LiveSwitcherTests\""))
            XCTAssertTrue(manifest.contains("dependencies: [\"LiveSwitcher\"]"))
        }
    }

    private func repoText(_ relativePath: String) throws -> String {
        try String(contentsOf: repoURL(relativePath), encoding: .utf8)
    }

    private func repoURL(_ relativePath: String) throws -> URL {
        var directory = URL(fileURLWithPath: #filePath)
        while directory.pathComponents.count > 1 {
            directory.deleteLastPathComponent()
            let rootMarker = directory.appendingPathComponent("script/check_release_hygiene.sh")
            if FileManager.default.fileExists(atPath: rootMarker.path) {
                let candidate = directory.appendingPathComponent(relativePath)
                if FileManager.default.fileExists(atPath: candidate.path) {
                    return candidate
                }
                break
            }
        }
        throw XCTSkip("Could not locate \(relativePath) from test source path.")
    }
}
