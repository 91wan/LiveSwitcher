import XCTest
@testable import LiveSwitcher

final class WebNavigationPolicyTests: XCTestCase {
    func testAllowsAboutAndSameDirectoryFiles() {
        let root = URL(fileURLWithPath: "/tmp/live-switcher/show", isDirectory: true)

        XCTAssertTrue(WebNavigationPolicy.shouldAllowNavigation(url: URL(string: "about:blank"), allowedRoot: root))
        XCTAssertTrue(WebNavigationPolicy.shouldAllowNavigation(url: URL(string: "about:srcdoc"), allowedRoot: root))
        XCTAssertTrue(WebNavigationPolicy.shouldAllowNavigation(url: root.appendingPathComponent("index.html"), allowedRoot: root))
        XCTAssertTrue(WebNavigationPolicy.shouldAllowNavigation(url: root.appendingPathComponent("assets/style.css"), allowedRoot: root))
    }

    func testRejectsRemoteAndOutsideDirectoryFiles() {
        let root = URL(fileURLWithPath: "/tmp/live-switcher/show", isDirectory: true)
        let parentFile = URL(fileURLWithPath: "/tmp/live-switcher/secret.html")
        let otherFile = URL(fileURLWithPath: "/tmp/other-show/index.html")

        XCTAssertFalse(WebNavigationPolicy.shouldAllowNavigation(url: URL(string: "https://example.com"), allowedRoot: root))
        XCTAssertFalse(WebNavigationPolicy.shouldAllowNavigation(url: parentFile, allowedRoot: root))
        XCTAssertFalse(WebNavigationPolicy.shouldAllowNavigation(url: otherFile, allowedRoot: root))
        XCTAssertFalse(WebNavigationPolicy.shouldAllowNavigation(url: nil, allowedRoot: root))
    }

    func testRejectsSymlinkNavigationEscapingAllowedRoot() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("WebNavigationPolicyTests-\(UUID().uuidString)", isDirectory: true)
        let root = directory.appendingPathComponent("show", isDirectory: true)
        let outside = directory.appendingPathComponent("outside", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let outsideFile = outside.appendingPathComponent("secret.html")
        try Data("<html>secret</html>".utf8).write(to: outsideFile)
        let symlink = root.appendingPathComponent("linked-outside", isDirectory: true)
        try FileManager.default.createSymbolicLink(at: symlink, withDestinationURL: outside)

        let escapedURL = symlink.appendingPathComponent("secret.html")

        XCTAssertFalse(WebNavigationPolicy.shouldAllowNavigation(url: escapedURL, allowedRoot: root))
    }

    func testReloadComparisonUsesNormalizedFilePaths() {
        let target = URL(fileURLWithPath: "/tmp/live-switcher/show/Opening Video.html")
        let current = URL(string: "file:///tmp/live-switcher/show/Opening%20Video.html")!

        XCTAssertFalse(WebNavigationPolicy.shouldReloadFileURL(current: current, target: target))
        XCTAssertTrue(WebNavigationPolicy.shouldReloadFileURL(
            current: URL(fileURLWithPath: "/tmp/live-switcher/show/Other.html"),
            target: target
        ))
        XCTAssertTrue(WebNavigationPolicy.shouldReloadFileURL(current: nil, target: target))
    }
}
