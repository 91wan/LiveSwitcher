import Foundation

enum RemoteControlHTTPMethod: String, Equatable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case options = "OPTIONS"
}

struct RemoteControlHTTPRequest: Equatable {
    var method: RemoteControlHTTPMethod
    var path: String
    var headers: [String: String]
    var body: Data

    init(
        method: RemoteControlHTTPMethod,
        path: String,
        headers: [String: String] = [:],
        body: Data = Data()
    ) {
        self.method = method
        self.path = path
        self.headers = Self.normalizedHeaders(headers)
        self.body = body
    }

    static func get(
        _ path: String,
        headers: [String: String] = [:]
    ) -> RemoteControlHTTPRequest {
        RemoteControlHTTPRequest(method: .get, path: path, headers: headers)
    }

    static func post(
        _ path: String,
        headers: [String: String] = [:],
        body: Data = Data()
    ) -> RemoteControlHTTPRequest {
        RemoteControlHTTPRequest(method: .post, path: path, headers: headers, body: body)
    }

    func header(_ name: String) -> String? {
        headers[name.lowercased()]
    }

    private static func normalizedHeaders(_ headers: [String: String]) -> [String: String] {
        var normalized: [String: String] = [:]
        for (key, value) in headers {
            let normalizedKey = key.lowercased()
            if normalized[normalizedKey] == nil {
                normalized[normalizedKey] = value
            }
        }
        return normalized
    }
}

enum RemoteControlHTTPParser {
    static func parse(_ rawRequest: String) -> RemoteControlHTTPRequest? {
        let normalized = rawRequest
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let parts = normalized.components(separatedBy: "\n\n")
        guard let headerBlock = parts.first else {
            return nil
        }

        let lines = headerBlock
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map(String.init)
        guard let requestLine = lines.first else {
            return nil
        }

        let requestParts = requestLine.split(separator: " ", omittingEmptySubsequences: true)
        guard requestParts.count >= 2,
              let method = RemoteControlHTTPMethod(rawValue: String(requestParts[0])) else {
            return nil
        }

        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let separator = line.firstIndex(of: ":") else {
                continue
            }
            let key = String(line[..<separator]).trimmingCharacters(in: .whitespacesAndNewlines)
            let value = String(line[line.index(after: separator)...]).trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedKey = key.lowercased()
            if headers[normalizedKey] == nil {
                headers[normalizedKey] = value
            }
        }
        let bodyText = parts.dropFirst().joined(separator: "\n\n")

        return RemoteControlHTTPRequest(
            method: method,
            path: String(requestParts[1]),
            headers: headers,
            body: Data(bodyText.utf8)
        )
    }
}
