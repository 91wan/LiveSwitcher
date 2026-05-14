import Foundation

enum PresentationAutomationService {
    static func keynoteStartScript(url: URL) -> String {
        let posixFile = AppleScriptSupport.posixFileExpression(url: url)
        return """
        tell application "Keynote"
            activate
            open \(posixFile)
            delay 1.0
            start (front document) from (slide 1 of front document)
        end tell
        """
    }

    static func wpsOpenScript(url: URL) -> String {
        let posixFile = AppleScriptSupport.posixFileExpression(url: url)
        return """
        tell application "WPS Office"
            activate
            open \(posixFile)
        end tell
        """
    }
}
