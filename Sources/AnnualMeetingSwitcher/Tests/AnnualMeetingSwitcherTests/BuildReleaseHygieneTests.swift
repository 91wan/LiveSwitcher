import XCTest
import CoreFoundation

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
        let version = try repoText("VERSION").trimmingCharacters(in: .whitespacesAndNewlines)
        let strings = [
            "CFBundleDisplayName": "LiveSwitcher",
            "CFBundleExecutable": "LiveSwitcher",
            "CFBundleIconFile": "AppIcon",
            "CFBundleIdentifier": "com.91wan.liveswitcher",
            "CFBundleName": "LiveSwitcher",
            "CFBundlePackageType": "APPL",
            "CFBundleShortVersionString": version,
            "CFBundleVersion": "1",
            "LSMinimumSystemVersion": "14.0",
            "NSAppleEventsUsageDescription": "Allow AppleScript control for presentation playback.",
            "NSAccessibilityUsageDescription": "Allow keyboard-event monitoring for PPT mode and presentation remote control.",
            "NSCameraUsageDescription": "Allow camera access for live input monitoring.",
            "NSMicrophoneUsageDescription": "Allow microphone access for audio monitoring.",
            "NSPrincipalClass": "NSApplication"
        ]
        let booleanKeys = ["NSAppleScriptEnabled", "NSHighResolutionCapable"]
        for entry in ["release", "debug"] {
            let root = try makeFixture()
            let result = try runBuild(entry, in: root)
            XCTAssertEqual(result.status, 0, result.output)
            let plist = try bundlePlist(root)
            XCTAssertEqual(Set(plist.keys), Set(strings.keys).union(booleanKeys).union(["CFBundleLocalizations"]))
            XCTAssertEqual(plist.count, 17)
            for (key, value) in strings {
                XCTAssertEqual(plist[key] as? String, value, key)
            }
            for key in booleanKeys {
                let value = try XCTUnwrap(plist[key] as? NSNumber, key)
                XCTAssertEqual(CFGetTypeID(value), CFBooleanGetTypeID(), key)
                XCTAssertTrue(value.boolValue, key)
            }
            XCTAssertEqual(plist["CFBundleLocalizations"] as? [String], ["en", "zh-Hans"])
        }
    }

    func testBuildScriptsCopySwiftPMResourceBundleIntoAppBundle() throws {
        for entry in ["release", "debug"] {
            let root = try makeFixture()
            let result = try runBuild(entry, in: root)
            XCTAssertEqual(result.status, 0, result.output)
            let contents = root.appendingPathComponent("dist/LiveSwitcher.app/Contents")
            let resources = contents.appendingPathComponent("Resources")
            let resourceBundle = resources.appendingPathComponent("LiveSwitcher_LiveSwitcher.bundle")
            let resource = resourceBundle.appendingPathComponent("fixture.txt")
            XCTAssertEqual(try Data(contentsOf: resource), Data("resource payload".utf8))
            XCTAssertEqual(try permissions(resource), 0o640)
            XCTAssertEqual(try permissions(resourceBundle), 0o750)
            XCTAssertEqual(try FileManager.default.destinationOfSymbolicLink(atPath: resourceBundle.appendingPathComponent("alias.txt").path), "fixture.txt")
            XCTAssertEqual(try Data(contentsOf: contents.appendingPathComponent("MacOS/LiveSwitcher")), Data("fixture binary".utf8))
            XCTAssertEqual(try permissions(contents.appendingPathComponent("MacOS/LiveSwitcher")), 0o751)
            XCTAssertEqual(try Data(contentsOf: resources.appendingPathComponent("AppIcon.icns")), Data("fixture icon".utf8))
            XCTAssertEqual(try permissions(resources.appendingPathComponent("AppIcon.icns")), 0o640)
        }
    }

    func testBuildScriptsDeclareSupportedBundleLocalizations() throws {
        for entry in ["release", "debug"] {
            let root = try makeFixture()
            let result = try runBuild(entry, in: root)
            XCTAssertEqual(result.status, 0, result.output)
            XCTAssertEqual(try bundlePlist(root)["CFBundleLocalizations"] as? [String], ["en", "zh-Hans"])
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

    func testBuildRoutesPreserveConfigurationAndSigningPolicies() throws {
        for entry in ["release", "debug"] {
            let root = try makeFixture()
            let result = try runBuild(entry, in: root)
            XCTAssertEqual(result.status, 0, result.output)
            let events = try trace(root)
            let buildArguments = entry == "release" ? "build -c release" : "build --package-path \(root.path)/Sources/AnnualMeetingSwitcher"
            let builds = events.filter { $0.hasPrefix("swift|") }
            XCTAssertEqual(builds.count, 2)
            for (event, arguments) in zip(builds, [buildArguments, "\(buildArguments) --show-bin-path"]) {
                let fields = event.split(separator: "|", omittingEmptySubsequences: false)
                XCTAssertEqual(fields.count, 3)
                let directory = URL(fileURLWithPath: String(try XCTUnwrap(fields.dropFirst().first)))
                XCTAssertEqual(directory.resolvingSymlinksInPath(), root.resolvingSymlinksInPath())
                XCTAssertEqual(fields.last.map(String.init), arguments)
            }
            let signing = events.filter { $0.hasPrefix("codesign|") }
            XCTAssertEqual(signing.first, "codesign|--force --deep --options runtime --sign - --entitlements \(root.path)/Sources/AnnualMeetingSwitcher/LiveSwitcher.entitlements \(root.path)/dist/LiveSwitcher.app")
            XCTAssertEqual(signing.count, entry == "release" ? 2 : 1)
            if entry == "release" {
                XCTAssertEqual(signing.last, "codesign|--verify --deep --strict \(root.path)/dist/LiveSwitcher.app")
            }
            XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("Sources/AnnualMeetingSwitcher/LiveSwitcher.entitlements")), try Data(contentsOf: repoURL("Sources/AnnualMeetingSwitcher/LiveSwitcher.entitlements")))
        }
    }

    func testSourcingRunnerDoesNotBuildKillOrLaunch() throws {
        let root = try makeFixture()
        let result = try run(sourceRunner, in: root)
        XCTAssertEqual(result.status, 0, result.output)
        XCTAssertEqual(try trace(root), [])
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("dist").path))
    }

    func testMissingBinaryLeavesPreviousBundleUntouched() throws {
        for entry in ["release", "debug"] {
            let root = try makeFixture()
            let marker = try previousBundleMarker(root)
            try FileManager.default.removeItem(at: root.appendingPathComponent("build output/LiveSwitcher"))
            let result = try runBuild(entry, in: root)
            XCTAssertEqual(result.status, 1, result.output)
            XCTAssertTrue(result.output.contains("built binary not found"))
            XCTAssertEqual(try String(contentsOf: marker, encoding: .utf8), "previous bundle")
            XCTAssertFalse(try trace(root).contains { $0.hasPrefix("codesign|") })
        }
    }

    func testResourceIconAndEntitlementsRemainOptional() throws {
        for entry in ["release", "debug"] {
            let root = try makeFixture()
            for path in ["build output/LiveSwitcher_LiveSwitcher.bundle", "Sources/AnnualMeetingSwitcher/AppIcon.icns", "Sources/AnnualMeetingSwitcher/LiveSwitcher.entitlements"] {
                try FileManager.default.removeItem(at: root.appendingPathComponent(path))
            }
            let result = try runBuild(entry, in: root)
            XCTAssertEqual(result.status, 0, result.output)
            let resources = root.appendingPathComponent("dist/LiveSwitcher.app/Contents/Resources")
            XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: resources.path), [])
            XCTAssertFalse(try trace(root).contains { $0.contains("--entitlements") })
            XCTAssertEqual(try bundlePlist(root).count, 17)
        }
    }

    func testSigningPoliciesPreserveCodesignAbsenceBehavior() throws {
        for entry in ["release", "debug"] {
            let root = try makeFixture()
            try FileManager.default.removeItem(at: root.appendingPathComponent("bin/codesign"))
            let result = try runBuild(entry, in: root)
            XCTAssertEqual(result.status, entry == "release" ? 127 : 0, result.output)
            XCTAssertFalse(try trace(root).contains { $0.hasPrefix("codesign|") })
        }
    }

    func testSigningFailurePropagatesForBothEntrypoints() throws {
        for entry in ["release", "debug"] {
            let root = try makeFixture()
            let result = try runBuild(entry, in: root, environment: ["FIXTURE_SIGN_STATUS": "37"])
            XCTAssertEqual(result.status, 37, result.output)
            XCTAssertFalse(try trace(root).contains { $0.hasPrefix("codesign|--verify") })
        }
    }

    func testReleaseVerificationFailurePropagatesButDebugDoesNotVerify() throws {
        for entry in ["release", "debug"] {
            let root = try makeFixture()
            let result = try runBuild(entry, in: root, environment: ["FIXTURE_VERIFY_STATUS": "43"])
            XCTAssertEqual(result.status, entry == "release" ? 43 : 0, result.output)
            XCTAssertEqual(try trace(root).contains { $0.hasPrefix("codesign|--verify") }, entry == "release")
        }
    }

    func testRunnerModesKeepPreparationAndDispatchOrder() throws {
        let modes = ["run", "--debug", "debug", "--logs", "logs", "--telemetry", "telemetry", "--verify", "verify", "invalid"]
        for mode in modes {
            let root = try makeFixture()
            let body = sourceRunner + #"""

            open_app() { printf 'open\n' >> "$FIXTURE_TRACE"; }
            verify_launch() { printf 'verify\n' >> "$FIXTURE_TRACE"; }
            stream_process_logs() { printf 'logs\n' >> "$FIXTURE_TRACE"; }
            stream_telemetry() { printf 'telemetry\n' >> "$FIXTURE_TRACE"; }
            MODE="$FIXTURE_MODE"
            main
            """#
            let result = try run(body, in: root, environment: ["FIXTURE_MODE": mode])
            XCTAssertEqual(result.status, mode == "invalid" ? 2 : 0, result.output)
            let events = try trace(root)
            XCTAssertEqual(events.first, "pkill|-x LiveSwitcher")
            XCTAssertEqual(events.filter { $0.hasPrefix("swift|") }.count, 2)
            let signedIndex = try XCTUnwrap(events.firstIndex { $0.hasPrefix("codesign|") })
            XCTAssertEqual(signedIndex, 3)
            let dispatch = Array(events.dropFirst(signedIndex + 1))
            switch mode {
            case "run": XCTAssertEqual(dispatch, ["open"])
            case "--debug", "debug": XCTAssertEqual(dispatch, ["lldb|-- \(root.path)/dist/LiveSwitcher.app/Contents/MacOS/LiveSwitcher"])
            case "--logs", "logs": XCTAssertEqual(dispatch, ["open", "verify", "logs"])
            case "--telemetry", "telemetry": XCTAssertEqual(dispatch, ["open", "verify", "telemetry"])
            case "--verify", "verify": XCTAssertEqual(dispatch, ["open", "verify"])
            default: XCTAssertEqual(dispatch, [])
            }
        }
        let root = try makeFixture()
        let direct = try run(#"/bin/bash "$FIXTURE_ROOT/script/build_and_run.sh" invalid"#, in: root)
        XCTAssertEqual(direct.status, 2, direct.output)
        XCTAssertTrue(direct.output.contains("usage:"))
        XCTAssertEqual(try trace(root).first, "pkill|-x LiveSwitcher")
        XCTAssertEqual(try trace(root).filter { $0.hasPrefix("swift|") }.count, 2)
    }

    func testBuildFailureDoesNotReplacePreviousBundle() throws {
        for entry in ["release", "debug"] {
            let root = try makeFixture()
            let marker = try previousBundleMarker(root)
            let result = try runBuild(entry, in: root, environment: ["FIXTURE_SWIFT_STATUS": "29"])
            XCTAssertEqual(result.status, 29, result.output)
            XCTAssertEqual(try String(contentsOf: marker, encoding: .utf8), "previous bundle")
            XCTAssertEqual(try trace(root).count, 1)
        }
    }

    func testMissingVersionFailsBeforeBuildPreparation() throws {
        for entry in ["release", "debug"] {
            let root = try makeFixture()
            let marker = try previousBundleMarker(root)
            try FileManager.default.removeItem(at: root.appendingPathComponent("VERSION"))
            let result = try runBuild(entry, in: root)
            XCTAssertNotEqual(result.status, 0, result.output)
            XCTAssertEqual(try trace(root), [])
            XCTAssertEqual(try String(contentsOf: marker, encoding: .utf8), "previous bundle")
        }
    }

    func testReleaseHygieneProtectsSharedWriterAndDelegates() throws {
        let script = try repoText("script/check_release_hygiene.sh")
        XCTAssertTrue(script.contains("require_file script/assemble_app_bundle.sh"))
        XCTAssertTrue(script.contains("require_literal_in_file script/assemble_app_bundle.sh \"$tcc_key\""))
        XCTAssertTrue(script.contains("script/build_and_run.sh script/assemble_app_bundle.sh Sources/AnnualMeetingSwitcher/build_v33.sh .github"))
        XCTAssertTrue(script.contains("assemble_live_switcher_bundle \"$build_dir\" if-available"))
        XCTAssertTrue(script.contains("assemble_live_switcher_bundle \"$BUILD_DIR\" required"))
    }

    private let sourceRunner = #"""
    swift() { return 91; }
    pkill() { return 0; }
    source "$FIXTURE_ROOT/script/build_and_run.sh"
    unset -f swift pkill
    """#

    private func makeFixture() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("LiveSwitcherBundleFixture-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        for path in ["VERSION", "script/build_and_run.sh", "script/assemble_app_bundle.sh", "Sources/AnnualMeetingSwitcher/build_v33.sh", "Sources/AnnualMeetingSwitcher/LiveSwitcher.entitlements"] {
            let destination = root.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: repoURL(path), to: destination)
        }
        let bin = root.appendingPathComponent("bin")
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        for (name, executable) in ["cat": "/bin/cat", "chmod": "/bin/chmod", "cp": "/bin/cp", "dirname": "/usr/bin/dirname", "mkdir": "/bin/mkdir", "rm": "/bin/rm", "tr": "/usr/bin/tr"] {
            try FileManager.default.createSymbolicLink(atPath: bin.appendingPathComponent(name).path, withDestinationPath: executable)
        }
        try writeExecutable(#"""
        #!/bin/bash
        printf 'swift|%s|%s\n' "$PWD" "$*" >> "$FIXTURE_TRACE"
        if [[ "$*" == *--show-bin-path* ]]; then printf '%s\n' "$FIXTURE_BUILD_DIR"; fi
        exit "${FIXTURE_SWIFT_STATUS:-0}"
        """#, to: bin.appendingPathComponent("swift"))
        try writeExecutable(#"""
        #!/bin/bash
        printf 'codesign|%s\n' "$*" >> "$FIXTURE_TRACE"
        if [[ "$1" == --verify ]]; then exit "${FIXTURE_VERIFY_STATUS:-0}"; fi
        exit "${FIXTURE_SIGN_STATUS:-0}"
        """#, to: bin.appendingPathComponent("codesign"))
        for command in ["pkill", "lldb"] {
            try writeExecutable("#!/bin/bash\nprintf '\(command)|%s\\n' \"$*\" >> \"$FIXTURE_TRACE\"\n", to: bin.appendingPathComponent(command))
        }
        let resourceBundle = root.appendingPathComponent("build output/LiveSwitcher_LiveSwitcher.bundle")
        try FileManager.default.createDirectory(at: resourceBundle, withIntermediateDirectories: true)
        try Data("fixture binary".utf8).write(to: root.appendingPathComponent("build output/LiveSwitcher"))
        try FileManager.default.setAttributes([.posixPermissions: 0o751], ofItemAtPath: root.appendingPathComponent("build output/LiveSwitcher").path)
        let resource = resourceBundle.appendingPathComponent("fixture.txt")
        try Data("resource payload".utf8).write(to: resource)
        try FileManager.default.setAttributes([.posixPermissions: 0o640], ofItemAtPath: resource.path)
        try FileManager.default.setAttributes([.posixPermissions: 0o750], ofItemAtPath: resourceBundle.path)
        try FileManager.default.createSymbolicLink(atPath: resourceBundle.appendingPathComponent("alias.txt").path, withDestinationPath: "fixture.txt")
        let icon = root.appendingPathComponent("Sources/AnnualMeetingSwitcher/AppIcon.icns")
        try Data("fixture icon".utf8).write(to: icon)
        try FileManager.default.setAttributes([.posixPermissions: 0o640], ofItemAtPath: icon.path)
        return root
    }

    private func writeExecutable(_ text: String, to url: URL) throws {
        try Data(text.utf8).write(to: url)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
    }

    private func runBuild(_ entry: String, in root: URL, environment: [String: String] = [:]) throws -> (status: Int32, output: String) {
        let body = entry == "release" ? #"/bin/bash "$FIXTURE_ROOT/Sources/AnnualMeetingSwitcher/build_v33.sh""# : sourceRunner + "\nbuild_bundle"
        return try run(body, in: root, environment: environment)
    }

    private func run(_ body: String, in root: URL, environment: [String: String] = [:]) throws -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", "umask 022\n" + body]
        process.currentDirectoryURL = root
        var variables = ProcessInfo.processInfo.environment
        variables["PATH"] = root.appendingPathComponent("bin").path
        variables["FIXTURE_ROOT"] = root.path
        variables["FIXTURE_BUILD_DIR"] = root.appendingPathComponent("build output").path
        variables["FIXTURE_TRACE"] = root.appendingPathComponent("trace.log").path
        variables.merge(environment) { _, new in new }
        process.environment = variables
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let output = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus, String(decoding: output, as: UTF8.self))
    }

    private func trace(_ root: URL) throws -> [String] {
        let url = root.appendingPathComponent("trace.log")
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        return try String(contentsOf: url, encoding: .utf8).split(separator: "\n").map(String.init)
    }

    private func bundlePlist(_ root: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: root.appendingPathComponent("dist/LiveSwitcher.app/Contents/Info.plist"))
        return try XCTUnwrap(PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any])
    }

    private func permissions(_ url: URL) throws -> Int {
        try XCTUnwrap(FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? NSNumber).intValue
    }

    private func previousBundleMarker(_ root: URL) throws -> URL {
        let marker = root.appendingPathComponent("dist/LiveSwitcher.app/previous.txt")
        try FileManager.default.createDirectory(at: marker.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("previous bundle".utf8).write(to: marker)
        return marker
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
