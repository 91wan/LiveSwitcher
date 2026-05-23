import AppKit
import XCTest
@testable import LiveSwitcher

final class WPSApplicationMonitorTests: XCTestCase {
    func testPreferredPIDChoosesRegularWPSApplication() {
        let snapshots = [
            WPSApplicationSnapshot(
                bundleIdentifier: "com.kingsoft.wpsoffice.mac",
                activationPolicy: .accessory,
                processIdentifier: 100
            ),
            WPSApplicationSnapshot(
                bundleIdentifier: "com.kingsoft.wpsoffice.mac",
                activationPolicy: .regular,
                processIdentifier: 200
            )
        ]

        XCTAssertEqual(WPSApplicationMonitor.preferredPID(from: snapshots), 200)
    }

    func testPreferredPIDFallsBackToFirstWPSApplication() {
        let snapshots = [
            WPSApplicationSnapshot(
                bundleIdentifier: "com.kingsoft.wpsoffice.mac",
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
}
