import Foundation

struct RemoteControlHTTPResponse: Equatable {
    private static let defaultHeaders: [String: String] = [
        "Cache-Control": "no-store",
        "Pragma": "no-cache",
        "X-Content-Type-Options": "nosniff",
        "Content-Security-Policy": "default-src 'self'; base-uri 'none'; frame-ancestors 'none'; form-action 'none'"
    ]

    var statusCode: Int
    var headers: [String: String]
    var body: Data

    init(
        statusCode: Int,
        headers: [String: String],
        body: Data
    ) {
        self.statusCode = statusCode
        self.headers = Self.mergingDefaultHeaders(with: headers)
        self.body = body
    }

    var bodyText: String {
        String(data: body, encoding: .utf8) ?? ""
    }

    func header(_ name: String) -> String? {
        headers[name.lowercased()]
    }

    private static func normalizedHeaders(_ headers: [String: String]) -> [String: String] {
        var normalized: [String: String] = [:]
        for (key, value) in headers {
            normalized[key.lowercased()] = value
        }
        return normalized
    }

    private static func mergingDefaultHeaders(with headers: [String: String]) -> [String: String] {
        var merged = normalizedHeaders(defaultHeaders)
        for (key, value) in headers {
            merged[key.lowercased()] = value
        }
        return merged
    }

    static func text(
        statusCode: Int,
        contentType: String,
        _ text: String
    ) -> RemoteControlHTTPResponse {
        RemoteControlHTTPResponse(
            statusCode: statusCode,
            headers: [
                "Content-Type": contentType,
                "Cache-Control": "no-store"
            ],
            body: Data(text.utf8)
        )
    }

    static func json(
        statusCode: Int,
        _ fields: [(String, Any)]
    ) -> RemoteControlHTTPResponse {
        let object = Dictionary(uniqueKeysWithValues: fields)
        let data = (try? JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys]
        )) ?? Data("{}".utf8)
        return RemoteControlHTTPResponse(
            statusCode: statusCode,
            headers: [
                "Content-Type": "application/json",
                "Cache-Control": "no-store"
            ],
            body: data
        )
    }

    static func jsonData(
        statusCode: Int,
        _ data: Data
    ) -> RemoteControlHTTPResponse {
        RemoteControlHTTPResponse(
            statusCode: statusCode,
            headers: [
                "Content-Type": "application/json",
                "Cache-Control": "no-store"
            ],
            body: data
        )
    }
}
