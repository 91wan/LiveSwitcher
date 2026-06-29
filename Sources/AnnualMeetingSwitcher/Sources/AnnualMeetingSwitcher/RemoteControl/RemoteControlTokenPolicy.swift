import Foundation

struct RemoteControlToken: Codable, Equatable, CustomStringConvertible {
    var value: String

    var description: String {
        redactedDescription
    }

    var redactedDescription: String {
        "<remote-token-redacted>"
    }
}

enum RemoteControlTokenPolicyError: Error, Equatable {
    case insufficientEntropy
}

enum RemoteControlTokenPolicy {
    static let minimumByteCount = 16
    static let defaultByteCount = 32

    static func makeToken(byteCount: Int = defaultByteCount) throws -> RemoteControlToken {
        guard byteCount >= minimumByteCount else {
            throw RemoteControlTokenPolicyError.insufficientEntropy
        }

        var generator = SystemRandomNumberGenerator()
        let bytes = (0..<byteCount).map { _ in
            UInt8.random(in: UInt8.min...UInt8.max, using: &generator)
        }
        return try makeToken(bytes: bytes)
    }

    static func makeToken(bytes: [UInt8]) throws -> RemoteControlToken {
        guard bytes.count >= minimumByteCount else {
            throw RemoteControlTokenPolicyError.insufficientEntropy
        }

        let value = Data(bytes)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")

        return RemoteControlToken(value: value)
    }
}
