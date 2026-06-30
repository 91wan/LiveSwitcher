import Foundation

struct RemoteControlRequestRouter {
    private enum ControllerClientAuthorization {
        case authorized(RemoteControlClientID?)
        case rejected(RemoteControlCommandRejection)
    }

    var token: RemoteControlToken
    var snapshotProvider: () -> RemoteControlSnapshot
    var commandContextProvider: () -> RemoteControlCommandValidationContext
    var dangerConfirmationIssuer: (RemoteControlCommandKind, RemoteControlClientID?) -> RemoteDangerConfirmationChallenge? = { _, _ in nil }
    var sessionCloseHandler: () -> RemoteControlSessionCloseResult = { .remoteDisabled }
    var sessionClaimHandler: (RemoteControlClientID) -> RemoteControlSessionClaimResult = { _ in .remoteDisabled }
    var requiresControllerClientID = false
    var canExecuteCommandFromClient: (RemoteControlClientID) -> Bool = { _ in true }
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
        case (.post, "/api/session/claim"):
            return withAuthorizedRequest(request) {
                sessionClaimResponse(for: request)
            }
        case (.post, "/api/danger-confirmation"):
            return withAuthorizedRequest(request) {
                dangerConfirmationResponse(for: request)
            }
        case (.post, "/api/session/close"):
            return withAuthorizedRequest(request) {
                sessionCloseResponse(for: request)
            }
        case (_, "/api/snapshot"),
             (_, "/api/command"),
             (_, "/api/session/claim"),
             (_, "/api/danger-confirmation"),
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

    private func dangerConfirmationResponse(for request: RemoteControlHTTPRequest) -> RemoteControlHTTPResponse {
        let clientID: RemoteControlClientID?
        switch controllerClientID(for: request) {
        case .authorized(let authorizedClientID):
            clientID = authorizedClientID
        case .rejected(let rejection):
            return rejectionResponse(rejection)
        }

        guard let payload = try? JSONSerialization.jsonObject(with: request.body) as? [String: Any],
              let kindText = payload["kind"] as? String else {
            return .json(statusCode: 400, [("error", "invalidDangerConfirmationJSON")])
        }

        switch RemoteControlCommandPolicy.resolveKind(kindText) {
        case .allowed(let kind):
            guard kind.isDangerous else {
                return rejectionResponse(.dangerConfirmationNotRequired)
            }

            guard let challenge = dangerConfirmationIssuer(kind, clientID) else {
                return rejectionResponse(.remoteDisabled)
            }

            return .json(statusCode: 202, [
                ("nonce", challenge.nonce),
                ("issuedAt", challenge.issuedAt.timeIntervalSince1970),
                ("expiresAt", challenge.expiresAt.timeIntervalSince1970),
                ("minimumHoldDuration", RemoteControlCommandPolicy.minimumDangerHoldDuration)
            ])
        case .rejected(let rejection):
            return rejectionResponse(rejection)
        }
    }

    private func sessionCloseResponse(for request: RemoteControlHTTPRequest) -> RemoteControlHTTPResponse {
        if let rejection = controllerClientRejection(for: request) {
            return rejectionResponse(rejection)
        }

        let result = sessionCloseHandler()
        guard result.closed else {
            return rejectionResponse(.remoteDisabled)
        }

        return .json(statusCode: 202, [
            ("closeRequested", true),
            ("closed", true)
        ])
    }

    private func sessionClaimResponse(for request: RemoteControlHTTPRequest) -> RemoteControlHTTPResponse {
        guard let payload = try? JSONSerialization.jsonObject(with: request.body) as? [String: Any],
              let rawClientID = payload["clientID"] as? String,
              let clientID = normalizedClientID(rawClientID) else {
            return .json(statusCode: 400, [("error", "invalidSessionClaimJSON")])
        }

        switch sessionClaimHandler(clientID) {
        case .controller:
            return .json(statusCode: 202, [
                ("claimed", true),
                ("role", RemoteControlClientRole.controller.rawValue)
            ])
        case .readOnly:
            return .json(statusCode: 409, [
                ("claimed", false),
                ("role", RemoteControlClientRole.readOnly.rawValue),
                ("error", "controllerAlreadyClaimed")
            ])
        case .remoteDisabled:
            return rejectionResponse(.remoteDisabled)
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

    private func commandResponse(for request: RemoteControlHTTPRequest) -> RemoteControlHTTPResponse {
        let clientID: RemoteControlClientID?
        switch controllerClientID(for: request) {
        case .authorized(let authorizedClientID):
            clientID = authorizedClientID
        case .rejected(let rejection):
            return rejectionResponse(rejection)
        }

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
            var context = commandContextProvider()
            context.clientID = clientID
            return commandExecutionResponse(
                RemoteControlCommandPolicy.validate(
                    command,
                    context: context
                )
            )
        case .rejected(let rejection):
            return rejectionResponse(rejection)
        }
    }

    private func controllerClientRejection(for request: RemoteControlHTTPRequest) -> RemoteControlCommandRejection? {
        if case .rejected(let rejection) = controllerClientID(for: request) {
            return rejection
        }
        return nil
    }

    private func controllerClientID(for request: RemoteControlHTTPRequest) -> ControllerClientAuthorization {
        guard requiresControllerClientID else {
            return .authorized(nil)
        }

        guard let clientID = normalizedClientID(request.header("x-remote-client-id")) else {
            return .rejected(.missingControllerClientID)
        }

        return canExecuteCommandFromClient(clientID) ? .authorized(clientID) : .rejected(.clientNotController)
    }

    private func rejectionResponse(
        _ rejection: RemoteControlCommandRejection
    ) -> RemoteControlHTTPResponse {
        .json(statusCode: statusCode(for: rejection), [("error", errorCode(for: rejection))])
    }

    private func statusCode(for rejection: RemoteControlCommandRejection) -> Int {
        switch rejection {
        case .forbiddenConfigurationCommand, .commandNotInRemoteMVP, .missingControllerClientID, .clientNotController:
            return 403
        case .unknownCommand:
            return 400
        case .remoteDisabled,
             .duplicateCommandID,
             .missingDangerConfirmation,
             .unknownDangerConfirmation,
             .expiredDangerConfirmation,
             .consumedDangerConfirmation,
             .mismatchedDangerConfirmationKind,
             .mismatchedDangerConfirmationClient,
             .insufficientDangerHoldDuration,
             .dangerConfirmationNotRequired:
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
        case .consumedDangerConfirmation:
            return "consumedDangerConfirmation"
        case .mismatchedDangerConfirmationKind:
            return "mismatchedDangerConfirmationKind"
        case .mismatchedDangerConfirmationClient:
            return "mismatchedDangerConfirmationClient"
        case .insufficientDangerHoldDuration:
            return "insufficientDangerHoldDuration"
        case .dangerConfirmationNotRequired:
            return "dangerConfirmationNotRequired"
        case .forbiddenConfigurationCommand:
            return "forbiddenConfigurationCommand"
        case .commandNotInRemoteMVP:
            return "commandNotInRemoteMVP"
        case .unknownCommand:
            return "unknownCommand"
        case .missingControllerClientID:
            return "missingControllerClientID"
        case .clientNotController:
            return "clientNotController"
        }
    }

    private func dangerConfirmation(from payload: [String: Any]) -> RemoteDangerConfirmation? {
        guard let object = payload["confirmation"] as? [String: Any],
              let nonce = object["nonce"] as? String else {
            return nil
        }

        return RemoteDangerConfirmation(nonce: nonce)
    }

    private func normalizedClientID(_ value: String?) -> RemoteControlClientID? {
        RemoteControlClientIDPolicy.normalized(value)
    }

    private func isSafePath(_ path: String) -> Bool {
        !path.contains("..") && path.hasPrefix("/")
    }

    private func notFound() -> RemoteControlHTTPResponse {
        .json(statusCode: 404, [("error", "notFound")])
    }
}
