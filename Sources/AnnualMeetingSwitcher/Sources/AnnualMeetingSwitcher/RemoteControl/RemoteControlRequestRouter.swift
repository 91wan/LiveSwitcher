import Foundation

struct RemoteControlRequestRouter {
    var token: RemoteControlToken
    var snapshotProvider: () -> RemoteControlSnapshot
    var commandContextProvider: () -> RemoteControlCommandValidationContext
    var commandExecutor: (RemoteControlAcceptedCommand) -> RemoteControlCommandExecutionResult = {
        .executed(RemoteControlCommandExecutionRecord(command: $0))
    }

    func route(_ request: RemoteControlHTTPRequest) -> RemoteControlHTTPResponse {
        guard isSafePath(request.path) else {
            return notFound()
        }

        switch (request.method, request.path) {
        case (.get, "/health"):
            return .json(statusCode: 200, [("status", "ok")])
        case (.get, "/"):
            return .text(
                statusCode: 200,
                contentType: "text/html; charset=utf-8",
                RemoteControlStaticPage.html
            )
        case (.get, "/remote.css"):
            return .text(
                statusCode: 200,
                contentType: "text/css; charset=utf-8",
                RemoteControlStaticPage.css
            )
        case (.get, "/remote.js"):
            return .text(
                statusCode: 200,
                contentType: "application/javascript; charset=utf-8",
                RemoteControlStaticPage.javascript
            )
        case (.get, "/api/snapshot"):
            return withAuthorizedRequest(request) {
                snapshotResponse()
            }
        case (.post, "/api/command"):
            return withAuthorizedRequest(request) {
                commandResponse(for: request)
            }
        case (.post, "/api/session/close"):
            return withAuthorizedRequest(request) {
                .json(statusCode: 202, [("closeRequested", true)])
            }
        case (_, "/api/snapshot"),
             (_, "/api/command"),
             (_, "/api/session/close"),
             (_, "/health"),
             (_, "/"),
             (_, "/remote.css"),
             (_, "/remote.js"):
            return .json(statusCode: 405, [("error", "methodNotAllowed")])
        default:
            return notFound()
        }
    }

    private func withAuthorizedRequest(
        _ request: RemoteControlHTTPRequest,
        perform: () -> RemoteControlHTTPResponse
    ) -> RemoteControlHTTPResponse {
        guard let authorization = request.header("authorization") else {
            return .json(statusCode: 401, [("error", "missingAuthorization")])
        }

        guard authorization == "Bearer \(token.value)" else {
            return .json(statusCode: 403, [("error", "invalidAuthorization")])
        }

        return perform()
    }

    private func snapshotResponse() -> RemoteControlHTTPResponse {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = (try? encoder.encode(snapshotProvider())) ?? Data("{}".utf8)
        return .jsonData(statusCode: 200, data)
    }

    private func commandResponse(for request: RemoteControlHTTPRequest) -> RemoteControlHTTPResponse {
        guard let payload = try? JSONSerialization.jsonObject(with: request.body) as? [String: Any],
              let idText = payload["id"] as? String,
              let id = UUID(uuidString: idText),
              let kindText = payload["kind"] as? String else {
            return .json(statusCode: 400, [("error", "invalidCommandJSON")])
        }

        switch RemoteControlCommandPolicy.resolveKind(kindText) {
        case .allowed(let kind):
            let command = RemoteControlCommand(
                id: id,
                kind: kind,
                confirmation: dangerConfirmation(from: payload)
            )
            return commandExecutionResponse(
                RemoteControlCommandPolicy.validate(
                    command,
                    context: commandContextProvider()
                )
            )
        case .rejected(let rejection):
            return rejectionResponse(rejection)
        }
    }

    private func commandExecutionResponse(
        _ result: RemoteControlCommandValidationResult
    ) -> RemoteControlHTTPResponse {
        switch result {
        case .accepted(let command):
            return executionResponse(commandExecutor(command))
        case .rejected(let rejection):
            return rejectionResponse(rejection)
        }
    }

    private func executionResponse(
        _ result: RemoteControlCommandExecutionResult
    ) -> RemoteControlHTTPResponse {
        switch result {
        case .executed(let record):
            return .json(statusCode: 202, [
                ("accepted", true),
                ("executed", true),
                ("id", record.id.uuidString),
                ("action", record.action),
                ("liveModeAction", record.liveModeAction),
                ("dangerous", record.isDangerous)
            ])
        case .rejected(let rejection):
            return rejectionResponse(rejection)
        }
    }

    private func rejectionResponse(
        _ rejection: RemoteControlCommandRejection
    ) -> RemoteControlHTTPResponse {
        .json(statusCode: statusCode(for: rejection), [("error", errorCode(for: rejection))])
    }

    private func statusCode(for rejection: RemoteControlCommandRejection) -> Int {
        switch rejection {
        case .forbiddenConfigurationCommand, .commandNotInRemoteMVP:
            return 403
        case .unknownCommand:
            return 400
        case .remoteDisabled,
             .duplicateCommandID,
             .missingDangerConfirmation,
             .unknownDangerConfirmation,
             .expiredDangerConfirmation,
             .insufficientDangerHoldDuration:
            return 409
        }
    }

    private func errorCode(for rejection: RemoteControlCommandRejection) -> String {
        switch rejection {
        case .remoteDisabled:
            return "remoteDisabled"
        case .duplicateCommandID:
            return "duplicateCommandID"
        case .missingDangerConfirmation:
            return "missingDangerConfirmation"
        case .unknownDangerConfirmation:
            return "unknownDangerConfirmation"
        case .expiredDangerConfirmation:
            return "expiredDangerConfirmation"
        case .insufficientDangerHoldDuration:
            return "insufficientDangerHoldDuration"
        case .forbiddenConfigurationCommand:
            return "forbiddenConfigurationCommand"
        case .commandNotInRemoteMVP:
            return "commandNotInRemoteMVP"
        case .unknownCommand:
            return "unknownCommand"
        }
    }

    private func dangerConfirmation(from payload: [String: Any]) -> RemoteDangerConfirmation? {
        guard let object = payload["confirmation"] as? [String: Any],
              let nonce = object["nonce"] as? String,
              let holdDuration = object["holdDuration"] as? Double else {
            return nil
        }

        return RemoteDangerConfirmation(nonce: nonce, holdDuration: holdDuration)
    }

    private func isSafePath(_ path: String) -> Bool {
        !path.contains("..") && path.hasPrefix("/")
    }

    private func notFound() -> RemoteControlHTTPResponse {
        .json(statusCode: 404, [("error", "notFound")])
    }
}
