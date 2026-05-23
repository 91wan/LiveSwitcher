import Foundation
import OSLog

enum LiveSwitcherTelemetry {
    private static let diagnosticsLogger = Logger(
        subsystem: AppConfiguration.bundleIdentifier,
        category: "Diagnostics"
    )

    private static let controlsLogger = Logger(
        subsystem: AppConfiguration.bundleIdentifier,
        category: "LiveControls"
    )

    private static let outputLogger = Logger(
        subsystem: AppConfiguration.bundleIdentifier,
        category: "Output"
    )

    static func diagnosticsCopied(summaryStatus: LivePreflightStatus) {
        diagnosticsLogger.info("Diagnostics copied; status=\(summaryStatus.rawValue, privacy: .public)")
    }

    static func diagnosticsSaved(summaryStatus: LivePreflightStatus) {
        diagnosticsLogger.info("Diagnostics saved; status=\(summaryStatus.rawValue, privacy: .public)")
    }

    static func supportReportCopied(summaryStatus: LivePreflightStatus) {
        diagnosticsLogger.info("Support report copied; status=\(summaryStatus.rawValue, privacy: .public)")
    }

    static func supportReportSaved(summaryStatus: LivePreflightStatus) {
        diagnosticsLogger.info("Support report saved; status=\(summaryStatus.rawValue, privacy: .public)")
    }

    static func preflightAction(_ action: LivePreflightActionKind, didMutateState: Bool) {
        diagnosticsLogger.info("Preflight action=\(action.rawValue, privacy: .public), mutated=\(didMutateState, privacy: .public)")
    }

    static func speakerModeChanged(isOn: Bool) {
        controlsLogger.info("Speaker mode changed; isOn=\(isOn, privacy: .public)")
    }

    static func panicModeChanged(isOn: Bool) {
        controlsLogger.info("Panic mode changed; isOn=\(isOn, privacy: .public)")
    }

    static func bgmTakeoverChanged(isActive: Bool) {
        controlsLogger.info("BGM takeover changed; isActive=\(isActive, privacy: .public)")
    }

    static func projectionToggle(isBroadcasting: Bool) {
        outputLogger.info("Projection toggle; isBroadcasting=\(isBroadcasting, privacy: .public)")
    }

    static func projectionFailClosed() {
        outputLogger.warning("Projection fail-closed; externalDisplay=false")
    }

    static func pageInterceptAutoReenabled(reason: PageInterceptReenableReason, didReenable: Bool) {
        controlsLogger.warning("Page intercept auto re-enabled; reason=\(reason.rawValue, privacy: .public), didReenable=\(didReenable, privacy: .public)")
    }

    static func pageInterceptEnabled() {
        controlsLogger.info("Page intercept enabled")
    }

    static func pageInterceptDisabled(reason: String) {
        controlsLogger.info("Page intercept disabled; reason=\(reason, privacy: .public)")
    }

    static func pageInterceptForwardedToWPS(direction: String, processIdentifier: pid_t) {
        controlsLogger.info(
            "Page intercept forwarded to WPS; direction=\(direction, privacy: .public), pid=\(processIdentifier, privacy: .public)"
        )
    }

    static func pageInterceptWPSNotRunning(direction: String) {
        controlsLogger.warning("Page intercept WPS target missing; direction=\(direction, privacy: .public)")
    }

    static func systemVolumeSynced(volume: Double, deviceID: UInt32) {
        controlsLogger.info(
            "System volume synced; volume=\(volume, privacy: .public), deviceID=\(deviceID, privacy: .public)"
        )
    }

    static func playbackReachedEnd() {
        controlsLogger.info("Program playback reached end")
    }

    static func appleScriptFailed(action: String, message: String) {
        controlsLogger.error(
            "AppleScript failed; action=\(action, privacy: .public), message=\(LiveSupportRedactor.safeText(message), privacy: .public)"
        )
    }
}
