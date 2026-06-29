import Foundation

struct RemoteControlHTTPResponse: Equatable {
    var statusCode: Int
    var headers: [String: String]
    var body: Data

    init(
        statusCode: Int,
        headers: [String: String],
        body: Data
    ) {
        self.statusCode = statusCode
        self.headers = Dictionary(
            uniqueKeysWithValues: headers.map { key, value in
                (key.lowercased(), value)
            }
        )
        self.body = body
    }

    var bodyText: String {
        String(data: body, encoding: .utf8) ?? ""
    }

    func header(_ name: String) -> String? {
        headers[name.lowercased()]
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
