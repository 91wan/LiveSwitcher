import XCTest
@testable import LiveSwitcher

final class RemoteControlWebUITests: XCTestCase {
    func testMobileHTMLDefinesSelfContainedChineseControllerShell() {
        let html = RemoteControlStaticPage.html

        XCTAssertTrue(html.contains(#"<meta name="viewport""#))
        XCTAssertTrue(html.contains("手机遥控"))
        XCTAssertTrue(html.contains("当前节目"))
        XCTAssertTrue(html.contains("下一节目"))
        XCTAssertTrue(html.contains("重新连接中"))
        XCTAssertTrue(html.contains(#"id="snapshot""#))
        XCTAssertTrue(html.contains(#"id="reconnect-banner""#))
        XCTAssertFalse(allStaticAssets.localizedStandardContains("https://"))
        XCTAssertFalse(allStaticAssets.localizedStandardContains("http://"))
        XCTAssertFalse(allStaticAssets.localizedStandardContains("fonts.googleapis"))
        XCTAssertFalse(allStaticAssets.localizedStandardContains("analytics"))
    }

    func testCommandButtonsAreLargeAndMapAllowedRemoteCommands() {
        let html = RemoteControlStaticPage.html
        let css = RemoteControlStaticPage.css

        [
            "takeNext",
            "toggleCurrentMediaPlayback",
            "returnCurrentMediaToStart",
            "toggleBGMPlayback",
            "selectPreviousBGM",
            "selectNextBGM",
            "toggleSpeakerMode"
        ].forEach {
            XCTAssertTrue(html.contains(#"data-command="\#($0)""#), "Missing command button for \($0)")
        }

        XCTAssertTrue(html.contains("切下一项"))
        XCTAssertTrue(html.contains("播放/暂停"))
        XCTAssertTrue(html.contains("回到开头"))
        XCTAssertTrue(html.contains("BGM"))
        XCTAssertTrue(html.contains("主讲人"))
        XCTAssertTrue(css.contains("min-height: 64px"))
    }

    func testDangerousControlsRequireLongPressAndServerConfirmation() {
        let html = RemoteControlStaticPage.html
        let javascript = RemoteControlStaticPage.javascript

        XCTAssertTrue(html.contains(#"data-command="toggleFadeToBlack""#))
        XCTAssertTrue(html.contains(#"data-command="togglePanic""#))
        XCTAssertTrue(html.contains(#"data-dangerous="true""#))
        XCTAssertTrue(html.contains(#"data-hold-ms="1200""#))
        XCTAssertTrue(html.contains("长按切黑"))
        XCTAssertTrue(html.contains("长按紧急切黑"))
        XCTAssertTrue(javascript.contains("pointerdown"))
        XCTAssertTrue(javascript.contains("pointerup"))
        XCTAssertTrue(javascript.contains("setTimeout"))
        XCTAssertTrue(javascript.contains("clearTimeout"))
        XCTAssertTrue(javascript.contains("/api/danger-confirmation"))
        XCTAssertTrue(javascript.contains("issueDangerConfirmation(button.dataset.command)"))
        XCTAssertTrue(javascript.contains(#"body: JSON.stringify({ kind })"#))
        XCTAssertTrue(javascript.contains("nonce: challenge.nonce"))
        XCTAssertFalse(javascript.contains("holdDuration"))
    }

    func testJavascriptReadsFragmentTokenPollsSnapshotAndPostsCommands() {
        let javascript = RemoteControlStaticPage.javascript

        XCTAssertTrue(javascript.contains("location.hash"))
        XCTAssertTrue(javascript.contains("URLSearchParams"))
        XCTAssertTrue(javascript.contains("token"))
        XCTAssertTrue(javascript.contains("/api/snapshot"))
        XCTAssertTrue(javascript.contains("/api/command"))
        XCTAssertTrue(javascript.contains("Authorization"))
        XCTAssertTrue(javascript.contains("setInterval"))
        XCTAssertTrue(javascript.contains("POST"))
        XCTAssertTrue(javascript.contains("crypto.randomUUID"))
        XCTAssertTrue(javascript.contains("disabled"))
        XCTAssertTrue(javascript.contains("reconnect"))
    }

    func testNonDangerButtonsUsePointerActivationForPhoneTaps() {
        let javascript = RemoteControlStaticPage.javascript

        XCTAssertTrue(javascript.contains("function activateCommandButton(button, event)"))
        XCTAssertTrue(javascript.contains(#"button.addEventListener("pointerup", (event) => activateCommandButton(button, event))"#))
        XCTAssertTrue(javascript.contains(#"button.addEventListener("click", (event) => event.preventDefault())"#))
        XCTAssertFalse(javascript.contains(#"button.addEventListener("click", () => {"#))
    }

    func testJavascriptClaimsSingleControllerAndPersistsClientID() {
        let javascript = RemoteControlStaticPage.javascript

        XCTAssertTrue(javascript.contains("localStorage"))
        XCTAssertTrue(javascript.contains("LiveSwitcher.remote.clientID"))
        XCTAssertTrue(javascript.contains("/api/session/claim"))
        XCTAssertTrue(javascript.contains("claimSession"))
        XCTAssertTrue(javascript.contains("X-Remote-Client-ID"))
        XCTAssertTrue(javascript.contains("clientID"))
        XCTAssertTrue(javascript.contains("clientRole"))
    }

    func testReadOnlyClientDisablesCommandsButKeepsSnapshotVisible() {
        let html = RemoteControlStaticPage.html
        let javascript = RemoteControlStaticPage.javascript

        XCTAssertTrue(html.contains("已有手机正在控制，本机只读"))
        XCTAssertTrue(javascript.contains(#"clientRole === "readOnly""#))
        XCTAssertTrue(javascript.contains("只读连接"))
        XCTAssertTrue(javascript.contains("updateButtonStates(data, true)"))
        XCTAssertTrue(javascript.contains(#"clientRole !== "controller""#))
        XCTAssertFalse(javascript.contains(#"snapshot.hidden = true"#))
    }

    func testStaticPageDoesNotIntroduceBuildStepOrExternalRuntimeReferences() {
        XCTAssertFalse(allStaticAssets.localizedStandardContains("<script src=\"https://"))
        XCTAssertFalse(allStaticAssets.localizedStandardContains("<link href=\"https://"))
        XCTAssertFalse(allStaticAssets.localizedStandardContains("npm"))
        XCTAssertFalse(allStaticAssets.localizedStandardContains("webpack"))
        XCTAssertFalse(allStaticAssets.localizedStandardContains("vite"))
        XCTAssertFalse(allStaticAssets.localizedStandardContains("tailwind"))
    }

    private var allStaticAssets: String {
        [
            RemoteControlStaticPage.html,
            RemoteControlStaticPage.css,
            RemoteControlStaticPage.javascript
        ].joined(separator: "\n")
    }
}
