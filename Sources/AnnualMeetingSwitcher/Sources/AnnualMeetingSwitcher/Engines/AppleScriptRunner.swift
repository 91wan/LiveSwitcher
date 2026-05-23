import Foundation

enum AppleScriptError: LocalizedError, Equatable {
    case compilationFailed(action: String, message: String)
    case executionFailed(action: String, message: String)

    var action: String {
        switch self {
        case .compilationFailed(let action, _),
             .executionFailed(let action, _):
            return action
        }
    }

    var message: String {
        switch self {
        case .compilationFailed(_, let message),
             .executionFailed(_, let message):
            return message
        }
    }

    var errorDescription: String? {
        switch self {
        case .compilationFailed(let action, let message):
            return "AppleScript compilation failed for \(action): \(message)"
        case .executionFailed(let action, let message):
            return "AppleScript execution failed for \(action): \(message)"
        }
    }
}

enum AppleScriptRunner {
    @discardableResult
    static func run(_ source: String, action: String) throws -> NSAppleEventDescriptor {
        var errorDict: NSDictionary?
        guard let script = NSAppleScript(source: source) else {
            let error = AppleScriptError.compilationFailed(
                action: action,
                message: "Unable to initialize NSAppleScript"
            )
            LiveSwitcherTelemetry.appleScriptFailed(action: error.action, message: error.message)
            throw error
        }

        script.compileAndReturnError(&errorDict)
        if let errorDict {
            let error = AppleScriptError.compilationFailed(
                action: action,
                message: appleScriptMessage(from: errorDict)
            )
            LiveSwitcherTelemetry.appleScriptFailed(action: error.action, message: error.message)
            throw error
        }

        let result = script.executeAndReturnError(&errorDict)
        if let errorDict {
            let error = AppleScriptError.executionFailed(
                action: action,
                message: appleScriptMessage(from: errorDict)
            )
            LiveSwitcherTelemetry.appleScriptFailed(action: error.action, message: error.message)
            throw error
        }

        return result
    }

    private static func appleScriptMessage(from errorDict: NSDictionary) -> String {
        if let message = errorDict[NSAppleScript.errorMessage] as? String,
           !message.isEmpty {
            return message
        }
        return errorDict.description
    }
}
