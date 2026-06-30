import XCTest
@testable import LiveSwitcher

final class RemoteControlTokenPolicyTests: XCTestCase {
    func testTokenRequiresAtLeast128BitsOfEntropy() {
        XCTAssertThrowsError(try RemoteControlTokenPolicy.makeToken(bytes: Array(repeating: 1, count: 15))) { error in
            XCTAssertEqual(error as? RemoteControlTokenPolicyError, .insufficientEntropy)
        }
    }

    func testGeneratedTokensAreURLSafeAndRedactedInDescriptions() throws {
        let token = try RemoteControlTokenPolicy.makeToken(bytes: Array(0..<32))

        XCTAssertFalse(token.value.contains("+"))
        XCTAssertFalse(token.value.contains("/"))
        XCTAssertFalse(token.value.contains("="))
        XCTAssertEqual(String(describing: token), "<remote-token-redacted>")
        XCTAssertEqual(token.redactedDescription, "<remote-token-redacted>")
    }

    func testRuntimeGeneratedTokensRotate() throws {
        let first = try RemoteControlTokenPolicy.makeToken()
        let second = try RemoteControlTokenPolicy.makeToken()

        XCTAssertNotEqual(first, second)
    }

    func testSessionEnableRotatesTokenAndClearsCommandHistory() throws {
        var store = RemoteControlSessionStore()
        let first = try RemoteControlTokenPolicy.makeToken(bytes: Array(repeating: 1, count: 32))
        let second = try RemoteControlTokenPolicy.makeToken(bytes: Array(repeating: 2, count: 32))
        let commandID = UUID()

        store.enable(token: first, now: Date(timeIntervalSince1970: 100))
        XCTAssertTrue(store.markCommandIDIfNew(commandID))
        XCTAssertFalse(store.markCommandIDIfNew(commandID))

        store.enable(token: second, now: Date(timeIntervalSince1970: 200))

        XCTAssertEqual(store.activeSession?.token, second)
        XCTAssertNotEqual(store.activeSession?.token, first)
        XCTAssertTrue(store.markCommandIDIfNew(commandID))
    }

    func testDisableInvalidatesSessionCommandIDsAndDangerConfirmations() throws {
        var store = RemoteControlSessionStore()
        let token = try RemoteControlTokenPolicy.makeToken(bytes: Array(repeating: 3, count: 32))

        store.enable(token: token, now: Date(timeIntervalSince1970: 100))
        let challenge = store.issueDangerConfirmation(
            nonce: "nonce-1",
            commandKind: .togglePanic,
            clientID: nil,
            now: Date(timeIntervalSince1970: 100),
            ttl: 5
        )
        XCTAssertEqual(store.dangerConfirmationExpiration(for: challenge.nonce), Date(timeIntervalSince1970: 105))

        store.disable()

        XCTAssertFalse(store.isEnabled)
        XCTAssertNil(store.activeSession)
        XCTAssertNil(store.dangerConfirmationExpiration(for: challenge.nonce))
    }
}
