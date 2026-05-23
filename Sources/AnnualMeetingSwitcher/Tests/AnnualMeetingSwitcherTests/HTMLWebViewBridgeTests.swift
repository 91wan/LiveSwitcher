import WebKit
import XCTest
@testable import LiveSwitcher

@MainActor
final class HTMLWebViewBridgeTests: XCTestCase {
    func testClearIfCurrentDoesNotClearNewerWebView() {
        let oldWebView = WKWebView(frame: .zero)
        let newWebView = WKWebView(frame: .zero)
        HTMLWebViewBridge.shared.register(newWebView)

        HTMLWebViewBridge.shared.clearIfCurrent(oldWebView)

        XCTAssertTrue(HTMLWebViewBridge.shared.hasActiveWebView)
        XCTAssertTrue(HTMLWebViewBridge.shared.isCurrent(newWebView))
    }

    func testClearIfCurrentClearsMatchingWebView() {
        let webView = WKWebView(frame: .zero)
        HTMLWebViewBridge.shared.register(webView)

        HTMLWebViewBridge.shared.clearIfCurrent(webView)

        XCTAssertFalse(HTMLWebViewBridge.shared.hasActiveWebView)
        XCTAssertFalse(HTMLWebViewBridge.shared.isCurrent(webView))
    }

    func testDispatchArrowCanBeCalledFromConcurrentThreadsWithoutTouchingWebViewOffMainActor() {
        let webView = WKWebView(frame: .zero)
        HTMLWebViewBridge.shared.register(webView)

        DispatchQueue.concurrentPerform(iterations: 64) { index in
            _ = HTMLWebViewBridge.shared.hasActiveWebView
            HTMLWebViewBridge.shared.dispatchArrowKey(isNext: index.isMultiple(of: 2))
        }

        XCTAssertTrue(HTMLWebViewBridge.shared.hasActiveWebView)
        XCTAssertTrue(HTMLWebViewBridge.shared.isCurrent(webView))
        HTMLWebViewBridge.shared.clearIfCurrent(webView)
    }
}
