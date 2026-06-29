import XCTest
@testable import LiveSwitcher

final class RemoteControlCommandPolicyTests: XCTestCase {
    func testAllowedCommandsMapToExistingLiveModeActions() {
        let expectedActions: [RemoteControlCommandKind: LiveModeActionKind] = [
            .takeNext: .takeNext,
            .toggleCurrentMediaPlayback: .toggleCurrentMediaPlayback,
            .returnCurrentMediaToStart: .returnCurrentMediaToStart,
            .toggleBGMPlayback: .bgmPlayPause,
            .selectPreviousBGM: .bgmPrevious,
            .selectNextBGM: .bgmNext,
            .toggleSpeakerMode: .toggleSpeakerMode,
            .toggleFadeToBlack: .toggleFadeToBlack,
            .togglePanic: .togglePanic
        ]

        XCTAssertEqual(Set(RemoteControlCommandKind.allCases), Set(expectedActions.keys))
        for (command, action) in expectedActions {
            XCTAssertEqual(command.liveModeAction, action)
            XCTAssertTrue(LiveModeSimplicityPolicy.isAllowed(action))
        }
    }

    func testForbiddenConfigurationCommandsAreRejectedBeforeExecution() {
        for surface in LiveModeConfigurationSurface.allCases {
            XCTAssertEqual(
                RemoteControlCommandPolicy.resolveKind(surface.rawValue),
                .rejected(.forbiddenConfigurationCommand)
            )
        }

        XCTAssertEqual(
            RemoteControlCommandPolicy.resolveKind("toggleProjection"),
            .rejected(.commandNotInRemoteMVP)
        )
        XCTAssertEqual(
            RemoteControlCommandPolicy.resolveKind("switchSource"),
            .rejected(.commandNotInRemoteMVP)
        )
    }

    func testDangerousCommandsRequireFreshConfirmationAndHoldDuration() {
        let now = Date(timeIntervalSince1970: 100)
        let commandID = UUID()
        let context = RemoteControlCommandValidationContext(
            isRemoteEnabled: true,
            acceptedCommandIDs: [],
            dangerConfirmationExpirations: ["nonce-1": now.addingTimeInterval(5)],
            now: now
        )

        XCTAssertEqual(
            RemoteControlCommandPolicy.validate(
                RemoteControlCommand(id: commandID, kind: .toggleFadeToBlack),
                context: context
            ),
            .rejected(.missingDangerConfirmation)
        )

        XCTAssertEqual(
            RemoteControlCommandPolicy.validate(
                RemoteControlCommand(
                    id: commandID,
                    kind: .togglePanic,
                    confirmation: RemoteDangerConfirmation(nonce: "nonce-1", holdDuration: 0.2)
                ),
                context: context
            ),
            .rejected(.insufficientDangerHoldDuration)
        )

        XCTAssertEqual(
            RemoteControlCommandPolicy.validate(
                RemoteControlCommand(
                    id: commandID,
                    kind: .togglePanic,
                    confirmation: RemoteDangerConfirmation(nonce: "nonce-1", holdDuration: 1.2)
                ),
                context: context
            ),
            .accepted(RemoteControlAcceptedCommand(
                id: commandID,
                kind: .togglePanic,
                liveModeAction: .togglePanic,
                isDangerous: true
            ))
        )

        XCTAssertEqual(
            RemoteControlCommandPolicy.validate(
                RemoteControlCommand(
                    id: commandID,
                    kind: .togglePanic,
                    confirmation: RemoteDangerConfirmation(nonce: "missing", holdDuration: 1.2)
                ),
                context: context
            ),
            .rejected(.unknownDangerConfirmation)
        )

        XCTAssertEqual(
            RemoteControlCommandPolicy.validate(
                RemoteControlCommand(
                    id: commandID,
                    kind: .togglePanic,
                    confirmation: RemoteDangerConfirmation(nonce: "expired", holdDuration: 1.2)
                ),
                context: RemoteControlCommandValidationContext(
                    isRemoteEnabled: true,
                    acceptedCommandIDs: [],
                    dangerConfirmationExpirations: ["expired": now.addingTimeInterval(-1)],
                    now: now
                )
            ),
            .rejected(.expiredDangerConfirmation)
        )
    }

    func testRemoteDisabledAndDuplicateCommandIDsAreRejected() {
        let id = UUID()
        let now = Date(timeIntervalSince1970: 100)

        XCTAssertEqual(
            RemoteControlCommandPolicy.validate(
                RemoteControlCommand(id: id, kind: .takeNext),
                context: RemoteControlCommandValidationContext(
                    isRemoteEnabled: false,
                    acceptedCommandIDs: [],
                    dangerConfirmationExpirations: [:],
                    now: now
                )
            ),
            .rejected(.remoteDisabled)
        )

        XCTAssertEqual(
            RemoteControlCommandPolicy.validate(
                RemoteControlCommand(id: id, kind: .takeNext),
                context: RemoteControlCommandValidationContext(
                    isRemoteEnabled: true,
                    acceptedCommandIDs: [id],
                    dangerConfirmationExpirations: [:],
                    now: now
                )
            ),
            .rejected(.duplicateCommandID)
        )
    }
}
