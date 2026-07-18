import Darwin
import Foundation

struct RemoteControlToken: Codable, Equatable, CustomStringConvertible {
    var value: String

    var description: String {
        redactedDescription
    }

    var redactedDescription: String {
        "<remote-token-redacted>"
    }

    func matchesBearerAuthorization(_ authorization: String) -> Bool {
        RemoteControlConstantTimeComparison.matches(
            authorization,
            expected: "Bearer \(value)"
        )
    }
}

private enum RemoteControlConstantTimeComparison {
    static func matches(_ candidate: String, expected: String) -> Bool {
        let candidateBytes = Array(candidate.utf8)
        let expectedBytes = Array(expected.utf8)
        var normalizedCandidate = Array(repeating: UInt8.zero, count: expectedBytes.count)
        let copiedByteCount = min(candidateBytes.count, expectedBytes.count)

        for index in 0..<copiedByteCount {
            normalizedCandidate[index] = candidateBytes[index]
        }

        let bytesMatch = normalizedCandidate.withUnsafeBytes { candidateBuffer in
            expectedBytes.withUnsafeBytes { expectedBuffer in
                timingsafe_bcmp(
                    candidateBuffer.baseAddress,
                    expectedBuffer.baseAddress,
                    expectedBytes.count
                ) == 0
            }
        }
        return bytesMatch && candidateBytes.count == expectedBytes.count
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
