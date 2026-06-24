import CoreGraphics
import XCTest
@testable import LiveSwitcher

final class TickerTrackGeometryTests: XCTestCase {
    func testTickerTracksAreOffscreenBeforeFirstConfiguration() async {
        let result = await MainActor.run {
            let engine = TickerEngine()
            let initialOffsetA = engine.offsetA
            let initialOffsetB = engine.offsetB
            engine.configure(containerWidth: 1920, measuredTextWidth: 640, speed: 80, resetPosition: true)
            let configuredOffset = engine.offsetA
            engine.configure(containerWidth: 0, measuredTextWidth: 640, speed: 80, resetPosition: true)
            let invalidOffsetA = engine.offsetA
            let invalidOffsetB = engine.offsetB
            engine.stop()
            return (initialOffsetA, initialOffsetB, configuredOffset, invalidOffsetA, invalidOffsetB)
        }

        XCTAssertGreaterThan(result.0, 4096)
        XCTAssertGreaterThan(result.1, 4096)
        XCTAssertGreaterThan(result.2, 1920)
        XCTAssertGreaterThan(result.3, 4096)
        XCTAssertGreaterThan(result.4, 4096)
    }

    func testInitialOffsetsStartOutsideRightEdge() {
        let geometry = TickerTrackGeometry(containerWidth: 1920, measuredTextWidth: 640)

        XCTAssertEqual(geometry.initialOffsetA, 1920 + TickerTrackGeometry.internalTextPadding, accuracy: 0.001)
        XCTAssertGreaterThan(geometry.initialOffsetA, 1920)
        XCTAssertEqual(geometry.initialOffsetB, geometry.initialOffsetA + geometry.textWidth + TickerTrackGeometry.trackGap, accuracy: 0.001)
    }

    func testResizeRebuildsOffsetsUsingNewWidth() async {
        let result = await MainActor.run {
            let engine = TickerEngine()
            engine.configure(containerWidth: 1280, measuredTextWidth: 480, speed: 80, resetPosition: true)
            let firstOffset = engine.offsetA
            engine.configure(containerWidth: 1920, measuredTextWidth: 480, speed: 80, resetPosition: true)
            let resizedOffset = engine.offsetA
            let containerWidth = engine.containerWidth
            engine.stop()
            return (firstOffset, resizedOffset, containerWidth)
        }

        XCTAssertEqual(result.0, 1280 + TickerTrackGeometry.internalTextPadding, accuracy: 0.001)
        XCTAssertEqual(result.1, 1920 + TickerTrackGeometry.internalTextPadding, accuracy: 0.001)
        XCTAssertEqual(result.2, 1920, accuracy: 0.001)
    }

    func testTextWidthChangeRebuildsTrackWidth() async {
        let result = await MainActor.run {
            let engine = TickerEngine()
            engine.configure(containerWidth: 1920, measuredTextWidth: 320, speed: 80, resetPosition: true)
            let firstTextWidth = engine.textWidth
            engine.configure(containerWidth: 1920, measuredTextWidth: 760, speed: 80, resetPosition: true)
            let resizedTextWidth = engine.textWidth
            let trackGap = engine.offsetB - engine.offsetA
            engine.stop()
            return (firstTextWidth, resizedTextWidth, trackGap)
        }

        XCTAssertEqual(result.0, 320, accuracy: 0.001)
        XCTAssertEqual(result.1, 760, accuracy: 0.001)
        XCTAssertEqual(result.2, 760 + TickerTrackGeometry.trackGap, accuracy: 0.001)
    }

    func testSpeedChangeKeepsSingleTimer() async {
        let result = await MainActor.run {
            let engine = TickerEngine()
            engine.configure(containerWidth: 1920, measuredTextWidth: 640, speed: 80, resetPosition: true)
            let firstTimerCount = engine.activeTimerCountForTesting
            engine.configure(containerWidth: 1920, measuredTextWidth: 640, speed: 160, resetPosition: false)
            let secondTimerCount = engine.activeTimerCountForTesting
            engine.stop()
            let stoppedTimerCount = engine.activeTimerCountForTesting
            return (firstTimerCount, secondTimerCount, stoppedTimerCount)
        }

        XCTAssertEqual(result.0, 1)
        XCTAssertEqual(result.1, 1)
        XCTAssertEqual(result.2, 0)
    }

    func testZeroWidthDoesNotStartTimer() async {
        let activeTimerCount = await MainActor.run {
            let engine = TickerEngine()
            engine.configure(containerWidth: 0, measuredTextWidth: 640, speed: 80, resetPosition: true)
            return engine.activeTimerCountForTesting
        }

        XCTAssertEqual(activeTimerCount, 0)
    }

    func testTickerEngineNoLongerUsesSentinelTextWidthOrStartedFlag() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/LowerThirdOverlay.swift")

        XCTAssertFalse(source.contains("textWidth == 800"))
        XCTAssertFalse(source.contains("private var started"))
    }
}
