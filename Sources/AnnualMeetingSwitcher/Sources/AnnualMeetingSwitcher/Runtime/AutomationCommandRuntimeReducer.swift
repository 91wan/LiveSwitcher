import Foundation

enum AutomationCommandRuntimeReducer {
    static func requestScript(
        script: String,
        action: String,
        effects: inout [LiveRuntimeEffect]
    ) {
        effects.append(.runAppleScript(script: script, action: action))
    }
}
