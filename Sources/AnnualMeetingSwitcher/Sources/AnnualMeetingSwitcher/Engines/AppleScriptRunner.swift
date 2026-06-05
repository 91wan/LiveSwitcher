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

enum AutomationFailureSanitizer {
    static func sanitizedMessage(from error: Error) -> String {
        failureCategory(from: error)
    }

    static func sanitizedSupportMessage(from error: Error) -> String {
        let category = sanitizedMessage(from: error)
        let detail = LiveSupportRedactor.safeEventDetail(rawMessage(from: error))
        guard !detail.isEmpty,
              !detail.localizedStandardContains("tell application"),
              !detail.localizedStandardContains("POSIX file")
        else {
            return category
        }
        return "\(category): \(detail)"
    }

    private static func failureCategory(from error: Error) -> String {
        if let error = error as? AppleScriptError {
            switch error {
            case .compilationFailed:
                return "compilationFailed"
            case .executionFailed(_, let message):
                return category(from: message, fallback: "executionFailed")
            }
        }

        let description = localizedDescription(for: error)
        return category(from: description, fallback: "unknown")
    }

    private static func category(from message: String, fallback: String) -> String {
        if message.localizedStandardContains("not authorized")
            || message.localizedStandardContains("not authorised")
            || message.localizedStandardContains("permission")
            || message.localizedStandardContains("accessibility")
            || message.localizedStandardContains("automation") {
            return "permissionDenied"
        }

        if message.localizedStandardContains("application was not found")
            || message.localizedStandardContains("application isn't running")
            || message.localizedStandardContains("application is not running")
            || message.localizedStandardContains("can't get application")
            || message.localizedStandardContains("cannot get application")
            || message.localizedStandardContains("not found") {
            return "applicationNotFound"
        }

        return fallback
    }

    private static func rawMessage(from error: Error) -> String {
        if let error = error as? AppleScriptError {
            return error.message
        }
        return localizedDescription(for: error)
    }

    private static func localizedDescription(for error: Error) -> String {
        if let description = (error as? LocalizedError)?.errorDescription,
           !description.isEmpty {
            return description
        }
        return String(describing: error)
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
