import XCTest
@testable import LiveSwitcher

final class RemoteControlSessionStoreTests: XCTestCase {
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
