import Foundation

enum AppleScriptSupport {
    static func quotedString(_ value: String) -> String {
        var escaped = "\""
        for character in value {
            switch character {
            case "\\":
                escaped += "\\\\"
            case "\"":
                escaped += "\\\""
            case "\n":
                escaped += "\\n"
            case "\r":
                escaped += "\\r"
            case "\t":
                escaped += "\\t"
            default:
                escaped.append(character)
            }
        }
        escaped += "\""
        return escaped
    }

    static func posixFileExpression(path: String) -> String {
        "POSIX file \(quotedString(path))"
    }

    static func posixFileExpression(url: URL) -> String {
        posixFileExpression(path: url.path)
    }
}
