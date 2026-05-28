import AppKit
import XCTest
@testable import LiveSwitcher

final class WPSApplicationMonitorTests: XCTestCase {
    func testPreferredPIDChoosesRegularWPSApplication() {
        let snapshots = [
            WPSApplicationSnapshot(
                bundleIdentifier: AppConfiguration.wpsBundleIdentifier,
                activationPolicy: .accessory,
                processIdentifier: 100
            ),
            WPSApplicationSnapshot(
                bundleIdentifier: AppConfiguration.wpsBundleIdentifier,
                activationPolicy: .regular,
                processIdentifier: 200
            )
        ]

        XCTAssertEqual(WPSApplicationMonitor.preferredPID(from: snapshots), 200)
    }

    func testPreferredPIDFallsBackToFirstWPSApplication() {
        let snapshots = [
            WPSApplicationSnapshot(
                bundleIdentifier: AppConfiguration.wpsBundleIdentifier,
                activationPolicy: .accessory,
                processIdentifier: 300
            ),
            WPSApplicationSnapshot(
                bundleIdentifier: "com.example.Other",
                activationPolicy: .regular,
                processIdentifier: 400
            )
        ]

        XCTAssertEqual(WPSApplicationMonitor.preferredPID(from: snapshots), 300)
    }

    func testPreferredPIDReturnsNilWhenWPSIsNotRunning() {
        let snapshots = [
            WPSApplicationSnapshot(
                bundleIdentifier: "com.example.Other",
                activationPolicy: .regular,
                processIdentifier: 500
            )
        ]

        XCTAssertNil(WPSApplicationMonitor.preferredPID(from: snapshots))
    }

    func testProductionWPSBundleIdentifierIsCentralizedInAppConfiguration() throws {
        let viewModel = try sourceText("ViewModel.swift")
        let probe = try sourceText("Engines/PresentationReadinessProbe.swift")
        let monitor = try sourceText("Engines/WPSApplicationMonitor.swift")

        XCTAssertTrue(viewModel.contains("AppConfiguration.wpsBundleIdentifier"))
        XCTAssertTrue(probe.contains("AppConfiguration.wpsBundleIdentifier"))
        XCTAssertTrue(monitor.contains("AppConfiguration.wpsBundleIdentifier"))
        XCTAssertFalse(viewModel.contains("\"com.kingsoft.wpsoffice.mac\""))
        XCTAssertFalse(probe.contains("\"com.kingsoft.wpsoffice.mac\""))
        XCTAssertFalse(monitor.contains("\"com.kingsoft.wpsoffice.mac\""))
    }

    private func sourceText(_ relativePath: String) throws -> String {
        var directory = URL(fileURLWithPath: #filePath)
        while directory.pathComponents.count > 1 {
            directory.deleteLastPathComponent()
            let candidate = directory
                .appendingPathComponent("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher")
                .appendingPathComponent(relativePath)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return try String(contentsOf: candidate, encoding: .utf8)
            }
        }
        throw XCTSkip("Could not locate \(relativePath) from test source path.")
    }
}
