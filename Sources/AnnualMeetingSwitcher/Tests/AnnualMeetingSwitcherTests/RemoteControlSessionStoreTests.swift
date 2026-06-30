import XCTest
@testable import LiveSwitcher

final class RemoteControlSessionStoreTests: XCTestCase {
    func testClientIDPolicyAcceptsSafeIDsAndRejectsMalformedValues() {
        let uuid = "00000000-0000-4000-8000-000000000001"

        XCTAssertEqual(RemoteControlClientIDPolicy.normalized(uuid), RemoteControlClientID(value: uuid))
        XCTAssertEqual(RemoteControlClientIDPolicy.normalized(" phone-A_1 "), RemoteControlClientID(value: "phone-A_1"))
        XCTAssertNil(RemoteControlClientIDPolicy.normalized(""))
        XCTAssertNil(RemoteControlClientIDPolicy.normalized("   "))
        XCTAssertNil(RemoteControlClientIDPolicy.normalized("short"))
        XCTAssertNil(RemoteControlClientIDPolicy.normalized("phone\nclient"))
        XCTAssertNil(RemoteControlClientIDPolicy.normalized(String(repeating: "a", count: 81)))
        XCTAssertNil(RemoteControlClientIDPolicy.normalized("phone<script>"))
    }

    func testFirstClientClaimsControllerAndSameClientCanReclaim() {
        var store = RemoteControlSessionStore()
        let clientID = RemoteControlClientID(value: "phone-a")
        store.enable(token: RemoteControlToken(value: "token-1"), now: Date(timeIntervalSince1970: 100))

        let first = store.claimController(clientID: clientID)
        let reconnect = store.claimController(clientID: clientID)

        XCTAssertEqual(first, .controller)
        XCTAssertEqual(reconnect, .controller)
        XCTAssertEqual(store.controllerClientID, clientID)
        XCTAssertTrue(store.canExecuteCommand(from: clientID))
    }

    func testSecondClientIsReadOnlyAndCannotExecuteCommands() {
        var store = RemoteControlSessionStore()
        let controller = RemoteControlClientID(value: "phone-a")
        let second = RemoteControlClientID(value: "phone-b")
        store.enable(token: RemoteControlToken(value: "token-1"), now: Date(timeIntervalSince1970: 100))
        XCTAssertEqual(store.claimController(clientID: controller), .controller)

        let secondClaim = store.claimController(clientID: second)

        XCTAssertEqual(secondClaim, .readOnly)
        XCTAssertTrue(store.canExecuteCommand(from: controller))
        XCTAssertFalse(store.canExecuteCommand(from: second))
    }

    func testEnableAndDisableClearControllerClaim() {
        var store = RemoteControlSessionStore()
        let clientID = RemoteControlClientID(value: "phone-a")
        store.enable(token: RemoteControlToken(value: "token-1"), now: Date(timeIntervalSince1970: 100))
        XCTAssertEqual(store.claimController(clientID: clientID), .controller)

        store.enable(token: RemoteControlToken(value: "token-2"), now: Date(timeIntervalSince1970: 200))
        XCTAssertNil(store.controllerClientID)
        XCTAssertFalse(store.canExecuteCommand(from: clientID))

        XCTAssertEqual(store.claimController(clientID: clientID), .controller)
        store.disable()

        XCTAssertNil(store.controllerClientID)
        XCTAssertFalse(store.canExecuteCommand(from: clientID))
    }
}
