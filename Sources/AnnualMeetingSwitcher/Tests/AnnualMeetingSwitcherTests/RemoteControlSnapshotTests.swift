import XCTest
@testable import LiveSwitcher

final class RemoteControlSnapshotTests: XCTestCase {
    func testSnapshotAllowsDisplayTitlesButRedactsFilePaths() {
        let snapshot = RemoteControlSnapshot(
            connectionState: .connected,
            currentProgramTitle: "/Users/operator/Documents/Private Opening.mp4",
            nextProgramTitle: "Guest Speech",
            isBroadcasting: true,
            isPanicActive: false,
            isFadeToBlackActive: false,
            isCurrentMediaPlaying: true,
            canToggleCurrentMedia: true,
            canReturnCurrentMediaToStart: true,
            currentBGMTitle: "file:///Users/operator/Music/Private Song.mp3",
            isBGMPlaying: true,
            canSelectPreviousBGM: true,
            canSelectNextBGM: true,
            isSpeakerMode: false,
            disabledReason: nil
        )

        XCTAssertEqual(snapshot.currentProgramTitle, "[redacted]")
        XCTAssertEqual(snapshot.nextProgramTitle, "Guest Speech")
        XCTAssertEqual(snapshot.currentBGMTitle, "[redacted]")
    }

    func testDiagnosticsSummaryDoesNotLeakCustomerContent() {
        let snapshot = RemoteControlSnapshot(
            connectionState: .connected,
            currentProgramTitle: "VIP Customer Opening",
            nextProgramTitle: "CEO Guest Speech",
            isBroadcasting: true,
            isPanicActive: true,
            isFadeToBlackActive: true,
            isCurrentMediaPlaying: false,
            canToggleCurrentMedia: true,
            canReturnCurrentMediaToStart: false,
            currentBGMTitle: "Private BGM Track",
            isBGMPlaying: false,
            canSelectPreviousBGM: false,
            canSelectNextBGM: true,
            isSpeakerMode: true,
            disabledReason: "operator disabled remote for VIP Customer"
        )

        let diagnostics = snapshot.redactedDiagnosticsSummary

        XCTAssertTrue(diagnostics.contains("connection=connected"))
        XCTAssertTrue(diagnostics.contains("broadcasting=true"))
        XCTAssertTrue(diagnostics.contains("panic=true"))
        XCTAssertFalse(diagnostics.contains("VIP Customer"))
        XCTAssertFalse(diagnostics.contains("CEO Guest"))
        XCTAssertFalse(diagnostics.contains("Private BGM"))
    }

    func testSnapshotRoundTripsThroughCodable() throws {
        let snapshot = RemoteControlSnapshot(
            connectionState: .enabled,
            currentProgramTitle: "Opening",
            nextProgramTitle: nil,
            isBroadcasting: false,
            isPanicActive: false,
            isFadeToBlackActive: false,
            isCurrentMediaPlaying: false,
            canToggleCurrentMedia: false,
            canReturnCurrentMediaToStart: false,
            currentBGMTitle: nil,
            isBGMPlaying: false,
            canSelectPreviousBGM: false,
            canSelectNextBGM: false,
            isSpeakerMode: false,
            disabledReason: "waiting for controller"
        )

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(RemoteControlSnapshot.self, from: data)

        XCTAssertEqual(decoded, snapshot)
    }

    func testDecodedSnapshotStillRedactsFilePaths() throws {
        let json = """
        {
          "connectionState": "connected",
          "currentProgramTitle": "/Users/operator/Documents/Private Opening.mp4",
          "nextProgramTitle": "Safe title",
          "isBroadcasting": true,
          "isPanicActive": false,
          "isFadeToBlackActive": false,
          "isCurrentMediaPlaying": true,
          "canToggleCurrentMedia": true,
          "canReturnCurrentMediaToStart": true,
          "currentBGMTitle": "file:///Users/operator/Music/Private Song.mp3",
          "isBGMPlaying": true,
          "canSelectPreviousBGM": true,
          "canSelectNextBGM": true,
          "isSpeakerMode": false,
          "disabledReason": null
        }
        """

        let snapshot = try JSONDecoder().decode(
            RemoteControlSnapshot.self,
            from: Data(json.utf8)
        )

        XCTAssertEqual(snapshot.currentProgramTitle, "[redacted]")
        XCTAssertEqual(snapshot.nextProgramTitle, "Safe title")
        XCTAssertEqual(snapshot.currentBGMTitle, "[redacted]")
    }
}
