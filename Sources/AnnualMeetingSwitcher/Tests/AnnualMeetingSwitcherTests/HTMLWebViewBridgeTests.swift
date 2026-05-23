import WebKit
import XCTest
@testable import LiveSwitcher

@MainActor
final class HTMLWebViewBridgeTests: XCTestCase {
    func testClearIfCurrentDoesNotClearNewerWebView() {
        let oldWebView = WKWebView(frame: .zero)
        let newWebView = WKWebView(frame: .zero)
        HTMLWebViewBridge.shared.webView = newWebView

        HTMLWebViewBridge.shared.clearIfCurrent(oldWebView)

        XCTAssertTrue(HTMLWebViewBridge.shared.webView === newWebView)
    }

    func testClearIfCurrentClearsMatchingWebView() {
        let webView = WKWebView(frame: .zero)
        HTMLWebViewBridge.shared.webView = webView

        HTMLWebViewBridge.shared.clearIfCurrent(webView)

        XCTAssertNil(HTMLWebViewBridge.shared.webView)
    }
}
