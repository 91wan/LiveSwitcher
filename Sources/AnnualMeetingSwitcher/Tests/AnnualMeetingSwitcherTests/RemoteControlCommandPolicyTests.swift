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

    func testDangerousCommandsRequireServerIssuedFreshMatchingUnconsumedConfirmation() {
        let now = Date(timeIntervalSince1970: 100)
        let commandID = UUID()
        let validChallenge = RemoteDangerConfirmationChallenge(
            nonce: "nonce-1",
            commandKind: .togglePanic,
            clientID: RemoteControlClientID(value: "phone-a-1"),
            issuedAt: now.addingTimeInterval(-1.2),
            expiresAt: now.addingTimeInterval(5),
            consumedAt: nil
        )
        let context = RemoteControlCommandValidationContext(
            isRemoteEnabled: true,
            acceptedCommandIDs: [],
            dangerConfirmationChallenges: ["nonce-1": validChallenge],
            clientID: RemoteControlClientID(value: "phone-a-1"),
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
                    confirmation: RemoteDangerConfirmation(nonce: "early")
                ),
                context: RemoteControlCommandValidationContext(
                    isRemoteEnabled: true,
                    acceptedCommandIDs: [],
                    dangerConfirmationChallenges: [
                        "early": RemoteDangerConfirmationChallenge(
                            nonce: "early",
                            commandKind: .togglePanic,
                            clientID: RemoteControlClientID(value: "phone-a-1"),
                            issuedAt: now.addingTimeInterval(-0.2),
                            expiresAt: now.addingTimeInterval(5),
                            consumedAt: nil
                        )
                    ],
                    clientID: RemoteControlClientID(value: "phone-a-1"),
                    now: now
                )
            ),
            .rejected(.insufficientDangerHoldDuration)
        )

        XCTAssertEqual(
            RemoteControlCommandPolicy.validate(
                RemoteControlCommand(
                    id: commandID,
                    kind: .togglePanic,
                    confirmation: RemoteDangerConfirmation(nonce: "nonce-1")
                ),
                context: context
            ),
            .accepted(RemoteControlAcceptedCommand(
                id: commandID,
                kind: .togglePanic,
                liveModeAction: .togglePanic,
                isDangerous: true,
                dangerConfirmationNonce: "nonce-1"
            ))
        )

        XCTAssertEqual(
            RemoteControlCommandPolicy.validate(
                RemoteControlCommand(
                    id: commandID,
                    kind: .toggleFadeToBlack,
                    confirmation: RemoteDangerConfirmation(nonce: "nonce-1")
                ),
                context: context
            ),
            .rejected(.mismatchedDangerConfirmationKind)
        )

        XCTAssertEqual(
            RemoteControlCommandPolicy.validate(
                RemoteControlCommand(
                    id: commandID,
                    kind: .togglePanic,
                    confirmation: RemoteDangerConfirmation(nonce: "consumed")
                ),
                context: RemoteControlCommandValidationContext(
                    isRemoteEnabled: true,
                    acceptedCommandIDs: [],
                    dangerConfirmationChallenges: [
                        "consumed": RemoteDangerConfirmationChallenge(
                            nonce: "consumed",
                            commandKind: .togglePanic,
                            clientID: RemoteControlClientID(value: "phone-a-1"),
                            issuedAt: now.addingTimeInterval(-1.2),
                            expiresAt: now.addingTimeInterval(5),
                            consumedAt: now.addingTimeInterval(-0.1)
                        )
                    ],
                    clientID: RemoteControlClientID(value: "phone-a-1"),
                    now: now
                )
            ),
            .rejected(.consumedDangerConfirmation)
        )

        XCTAssertEqual(
            RemoteControlCommandPolicy.validate(
                RemoteControlCommand(
                    id: commandID,
                    kind: .togglePanic,
                    confirmation: RemoteDangerConfirmation(nonce: "missing")
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
                    confirmation: RemoteDangerConfirmation(nonce: "expired")
                ),
                context: RemoteControlCommandValidationContext(
                    isRemoteEnabled: true,
                    acceptedCommandIDs: [],
                    dangerConfirmationChallenges: [
                        "expired": RemoteDangerConfirmationChallenge(
                            nonce: "expired",
                            commandKind: .togglePanic,
                            clientID: RemoteControlClientID(value: "phone-a-1"),
                            issuedAt: now.addingTimeInterval(-1.2),
                            expiresAt: now.addingTimeInterval(-1),
                            consumedAt: nil
                        )
                    ],
                    clientID: RemoteControlClientID(value: "phone-a-1"),
                    now: now
                )
            ),
            .rejected(.expiredDangerConfirmation)
        )

        XCTAssertEqual(
            RemoteControlCommandPolicy.validate(
                RemoteControlCommand(
                    id: commandID,
                    kind: .togglePanic,
                    confirmation: RemoteDangerConfirmation(nonce: "nonce-1")
                ),
                context: RemoteControlCommandValidationContext(
                    isRemoteEnabled: true,
                    acceptedCommandIDs: [],
                    dangerConfirmationChallenges: ["nonce-1": validChallenge],
                    clientID: RemoteControlClientID(value: "phone-b-1"),
                    now: now
                )
            ),
            .rejected(.mismatchedDangerConfirmationClient)
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
                    dangerConfirmationChallenges: [:],
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
                    dangerConfirmationChallenges: [:],
                    now: now
                )
            ),
            .rejected(.duplicateCommandID)
        )
    }
}
