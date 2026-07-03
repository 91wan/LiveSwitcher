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

    func testMediaProgramControlsShareRoleAndBGMControlsStayDistinct() {
        let html = RemoteControlStaticPage.html
        let css = RemoteControlStaticPage.css

        XCTAssertTrue(html.contains(#"<article class="snapshot-card program-status current-card">"#))
        XCTAssertTrue(html.contains(#"<article class="snapshot-card program-status next-card">"#))
        XCTAssertTrue(html.contains(#"<button class="command-button primary program-action" data-command="takeNext">"#))
        XCTAssertTrue(html.contains(#"<button class="command-button program-action" data-command="toggleCurrentMediaPlayback">"#))
        XCTAssertTrue(html.contains(#"<button class="command-button program-action" data-command="returnCurrentMediaToStart">"#))
        XCTAssertTrue(html.contains(#"<button class="command-button bgm-action" data-command="selectPreviousBGM">"#))
        XCTAssertTrue(html.contains(#"<button class="command-button bgm-action" data-command="toggleBGMPlayback">"#))
        XCTAssertTrue(html.contains(#"<button class="command-button bgm-action" data-command="selectNextBGM">"#))

        XCTAssertTrue(css.contains(".program-action"))
        XCTAssertTrue(css.contains(".program-status"))
        XCTAssertTrue(css.contains(".bgm-action"))
        XCTAssertTrue(css.contains(".command-button:disabled"))
        XCTAssertTrue(css.contains(".command-button.danger"))
        XCTAssertTrue(css.contains(".command-button.panic"))

        XCTAssertFalse(html.contains(#"data-command="previousProgram""#))
        XCTAssertFalse(html.contains(#"data-command="selectPreviousProgram""#))
        XCTAssertFalse(html.contains(#"data-command="takePrevious""#))
        XCTAssertFalse(html.contains(#"class="command-button danger program-action""#))
        XCTAssertFalse(html.contains(#"class="command-button danger bgm-action""#))
    }

    func testSnapshotTitlesAreClampedSoLongBGMNamesDoNotStretchRemotePage() {
        let css = RemoteControlStaticPage.css

        XCTAssertTrue(css.contains(".snapshot-card strong"))
        XCTAssertTrue(css.contains("display: -webkit-box"))
        XCTAssertTrue(css.contains("-webkit-box-orient: vertical"))
        XCTAssertTrue(css.contains("-webkit-line-clamp: 2"))
        XCTAssertTrue(css.contains("overflow: hidden"))
        XCTAssertTrue(css.contains("overflow-wrap: anywhere"))
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

    func testCommandIDFallbackAlwaysGeneratesUUIDShapedValuesForInsecureLANBrowsers() {
        let javascript = RemoteControlStaticPage.javascript

        XCTAssertTrue(javascript.contains("function uuidV4()"))
        XCTAssertTrue(javascript.contains("crypto.getRandomValues"))
        XCTAssertTrue(javascript.contains("bytes[6] = (bytes[6] & 0x0f) | 0x40"))
        XCTAssertTrue(javascript.contains("bytes[8] = (bytes[8] & 0x3f) | 0x80"))
        XCTAssertTrue(javascript.contains("padStart(2, \"0\")"))
        XCTAssertTrue(javascript.contains("return uuidV4();"))
        XCTAssertFalse(javascript.contains("`${Date.now()}-${Math.random().toString(16).slice(2)}`"))
    }

    func testNonDangerButtonsUseTouchAndClickFallbackActivationForPhoneTaps() {
        let javascript = RemoteControlStaticPage.javascript

        XCTAssertTrue(javascript.contains("function activateCommandButton(button, event)"))
        XCTAssertTrue(javascript.contains("button.lastActivatedAt"))
        XCTAssertTrue(javascript.contains("Date.now() - lastActivatedAt < 350"))
        XCTAssertTrue(javascript.contains(#"button.addEventListener("pointerup", (event) => activateCommandButton(button, event))"#))
        XCTAssertTrue(javascript.contains(#"button.addEventListener("touchend", (event) => activateCommandButton(button, event))"#))
        XCTAssertTrue(javascript.contains(#"button.addEventListener("click", (event) => activateCommandButton(button, event))"#))
        XCTAssertFalse(javascript.contains(#"button.addEventListener("click", () => {"#))
    }

    func testJavascriptClaimsSingleControllerAndPersistsClientID() {
        let javascript = RemoteControlStaticPage.javascript

        XCTAssertTrue(javascript.contains("sessionStorage"))
        XCTAssertTrue(javascript.contains("LiveSwitcher.remote.controllerClientID"))
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

    func testCommandsWaitForControllerClaimBeforePosting() {
        let javascript = RemoteControlStaticPage.javascript

        XCTAssertTrue(javascript.contains("async function sendCommand(kind, confirmation)"))
        XCTAssertTrue(javascript.contains("await claimSession();"))
        XCTAssertTrue(javascript.contains(#"if (clientRole !== "controller")"#))
        XCTAssertTrue(javascript.contains(#"return;"#))
    }

    func testCommandPostFailuresAreVisibleWithoutLeakingSensitiveValues() {
        let html = RemoteControlStaticPage.html
        let javascript = RemoteControlStaticPage.javascript

        XCTAssertTrue(html.contains(#"id="command-status""#))
        XCTAssertTrue(javascript.contains("const commandStatus"))
        XCTAssertTrue(javascript.contains("const commandLabels"))
        XCTAssertTrue(javascript.contains(#"takeNext: "切下一项""#))
        XCTAssertTrue(javascript.contains(#"toggleCurrentMediaPlayback: "播放/暂停""#))
        XCTAssertTrue(javascript.contains(#"returnCurrentMediaToStart: "回到开头""#))
        XCTAssertTrue(javascript.contains(#"toggleBGMPlayback: "BGM 播放/暂停""#))
        XCTAssertTrue(javascript.contains(#"selectPreviousBGM: "上一首""#))
        XCTAssertTrue(javascript.contains(#"selectNextBGM: "下一首""#))
        XCTAssertTrue(javascript.contains(#"toggleSpeakerMode: "主讲人模式""#))
        XCTAssertTrue(javascript.contains(#"toggleFadeToBlack: "切黑""#))
        XCTAssertTrue(javascript.contains(#"togglePanic: "紧急切黑""#))
        XCTAssertTrue(javascript.contains("let latestSnapshot = null"))
        XCTAssertTrue(javascript.contains("latestSnapshot = data"))
        XCTAssertTrue(javascript.contains("function commandPendingCopy(kind)"))
        XCTAssertTrue(javascript.contains("function commandSuccessCopy(kind, data = latestSnapshot)"))
        XCTAssertTrue(javascript.contains("function commandFailureCopy(kind, errorCode)"))
        XCTAssertTrue(javascript.contains(#"return `${commandLabel(kind)} 发送中`"#))
        XCTAssertTrue(javascript.contains(#"return data.isCurrentMediaPlaying ? "媒体暂停 已执行" : "媒体播放 已执行""#))
        XCTAssertTrue(javascript.contains(#"return data.isBGMPlaying ? "BGM 暂停 已执行" : "BGM 播放 已执行""#))
        XCTAssertTrue(javascript.contains(#"return data.isSpeakerMode ? "主讲人模式 已关" : "主讲人模式 已开""#))
        XCTAssertTrue(javascript.contains(#"return data.isFadeToBlackActive ? "切黑 已解除" : "切黑 已开启""#))
        XCTAssertTrue(javascript.contains(#"return data.isPanicActive ? "紧急切黑 已解除" : "紧急切黑 已开启""#))
        XCTAssertTrue(javascript.contains(#"return `${commandLabel(kind)} 已执行`"#))
        XCTAssertTrue(javascript.contains(#"return `${commandLabel(kind)} 失败：${safeErrorCopy(errorCode)}`"#))
        XCTAssertTrue(javascript.contains("只读连接，不能控制"))
        XCTAssertTrue(javascript.contains("网络断开"))
        XCTAssertTrue(javascript.contains("payload.error || \"unknown\""))
        XCTAssertFalse(javascript.contains("最近命令已执行"))
        XCTAssertFalse(javascript.contains("最近命令已发送"))
        XCTAssertFalse(javascript.contains("主讲人 已切换"))
        XCTAssertFalse(javascript.contains("播放/暂停 已执行"))
        XCTAssertFalse(javascript.contains("BGM 播放/暂停 已执行"))
        XCTAssertFalse(javascript.contains("command-status-token"))
        XCTAssertFalse(javascript.contains("command-status-nonce"))
    }

    func testCommandFeedbackDoesNotUseSnapshotOrSensitiveValues() {
        let javascript = RemoteControlStaticPage.javascript

        XCTAssertFalse(javascript.contains("setCommandStatus(data.currentProgramTitle"))
        XCTAssertFalse(javascript.contains("setCommandStatus(data.nextProgramTitle"))
        XCTAssertFalse(javascript.contains("setCommandStatus(data.currentBGMTitle"))
        XCTAssertFalse(javascript.contains("setCommandStatus(token"))
        XCTAssertFalse(javascript.contains("setCommandStatus(clientID"))
        XCTAssertFalse(javascript.contains("setCommandStatus(challenge.nonce"))
        XCTAssertFalse(javascript.contains("setCommandStatus(location"))
        XCTAssertFalse(javascript.contains("VIP Customer"))
        XCTAssertFalse(javascript.contains("Private BGM"))
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
