import Foundation
import Network

protocol RemoteControlListening: AnyObject {
    var port: UInt16? { get }
    var requestHandler: ((String) -> Data)? { get set }
    var failureHandler: (() -> Void)? { get set }

    func start() throws
    func cancel()
}

struct RemoteControlServerEndpoint: Equatable {
    var port: UInt16
    var token: RemoteControlToken
}

struct RemoteControlServerFailure: Equatable {
    var reason: String
}

enum RemoteControlServerEnableResult: Equatable {
    case started(RemoteControlServerEndpoint)
    case failed(RemoteControlServerFailure)
}

final class RemoteControlServer {
    typealias ListenerFactory = (UInt16?) throws -> RemoteControlListening

    private let listenerFactory: ListenerFactory
    private let tokenProvider: () throws -> RemoteControlToken
    private let snapshotProvider: () -> RemoteControlSnapshot
    private let commandContextProvider: () -> RemoteControlCommandValidationContext
    private let commandExecutor: (RemoteControlAcceptedCommand) -> RemoteControlCommandExecutionResult
    private let sessionCloseObserver: () -> Void
    private var listener: RemoteControlListening?
    private var sessionStore = RemoteControlSessionStore()
    private var lastFailureReason: String?

    private(set) var activeEndpoint: RemoteControlServerEndpoint?

    var isEnabled: Bool {
        listener != nil && sessionStore.isEnabled
    }

    var activeSession: RemoteControlSession? {
        sessionStore.activeSession
    }

    var redactedDiagnosticsSummary: String {
        [
            "enabled=\(isEnabled)",
            "port=\(activeEndpoint.map { String($0.port) } ?? "none")",
            "token=\(activeSession == nil ? "none" : RemoteControlToken(value: "").redactedDescription)",
            "failure=\(lastFailureReason ?? "none")"
        ].joined(separator: ",")
    }

    init(
        listenerFactory: @escaping ListenerFactory = { try RemoteControlNWListener(port: $0) },
        tokenProvider: @escaping () throws -> RemoteControlToken = { try RemoteControlTokenPolicy.makeToken() },
        snapshotProvider: @escaping () -> RemoteControlSnapshot,
        commandContextProvider: @escaping () -> RemoteControlCommandValidationContext,
        sessionCloseObserver: @escaping () -> Void = {},
        commandExecutor: @escaping (RemoteControlAcceptedCommand) -> RemoteControlCommandExecutionResult = {
            .executed(RemoteControlCommandExecutionRecord(command: $0))
        }
    ) {
        self.listenerFactory = listenerFactory
        self.tokenProvider = tokenProvider
        self.snapshotProvider = snapshotProvider
        self.commandContextProvider = commandContextProvider
        self.sessionCloseObserver = sessionCloseObserver
        self.commandExecutor = commandExecutor
    }

    deinit {
        listener?.cancel()
    }

    func enable(
        port: UInt16? = nil,
        now: Date = Date()
    ) -> RemoteControlServerEnableResult {
        disable()

        do {
            let token = try tokenProvider()
            let newListener = try listenerFactory(port)
            newListener.requestHandler = makeRequestHandler(token: token)
            newListener.failureHandler = { [weak self] in
                self?.handleListenerFailure()
            }

            do {
                try newListener.start()
            } catch {
                newListener.cancel()
                return fail(reason: "listenerStartFailed")
            }

            let endpoint = RemoteControlServerEndpoint(
                port: resolvedEndpointPort(listenerPort: newListener.port, requestedPort: port),
                token: token
            )
            sessionStore.enable(token: token, now: now)
            listener = newListener
            activeEndpoint = endpoint
            lastFailureReason = nil
            return .started(endpoint)
        } catch {
            return fail(reason: "listenerStartFailed")
        }
    }

    func disable() {
        listener?.cancel()
        listener = nil
        activeEndpoint = nil
        sessionStore.disable()
    }

    private func makeRequestHandler(token: RemoteControlToken) -> (String) -> Data {
        { [weak self, snapshotProvider] rawRequest in
            guard let request = RemoteControlHTTPParser.parse(rawRequest) else {
                return RemoteControlHTTPWireCodec.serialize(.json(
                    statusCode: 400,
                    [("error", "invalidRequest")]
                ))
            }

            guard self?.acceptsRequest(request, token: token) == true else {
                return RemoteControlHTTPWireCodec.serialize(.json(
                    statusCode: 403,
                    [("error", "invalidAuthorization")]
                ))
            }

            var shouldCloseSession = false
            let router = RemoteControlRequestRouter(
                token: token,
                snapshotProvider: snapshotProvider,
                commandContextProvider: {
                    self?.commandValidationContext() ?? Self.disabledCommandContext()
                },
                dangerConfirmationIssuer: { kind in
                    self?.issueDangerConfirmation(kind: kind)
                },
                sessionCloseHandler: {
                    guard self?.isEnabled == true else {
                        return .remoteDisabled
                    }
                    shouldCloseSession = true
                    return .closed
                },
                commandExecutor: {
                    self?.executeAcceptedCommand($0) ?? .rejected(.remoteDisabled)
                }
            )
            let data = RemoteControlHTTPWireCodec.serialize(router.route(request))
            if shouldCloseSession {
                self?.closeSessionAfterResponse()
            }
            return data
        }
    }

    private func acceptsRequest(_ request: RemoteControlHTTPRequest, token: RemoteControlToken) -> Bool {
        guard request.path.hasPrefix("/api/") else {
            return true
        }

        return isEnabled && activeSession?.token == token
    }

    private func commandValidationContext() -> RemoteControlCommandValidationContext {
        var context = commandContextProvider()
        context.isRemoteEnabled = context.isRemoteEnabled && isEnabled
        context.acceptedCommandIDs.formUnion(sessionStore.acceptedCommandIDs)
        context.dangerConfirmationChallenges.merge(sessionStore.dangerConfirmationChallenges) { current, _ in
            current
        }
        return context
    }

    private func issueDangerConfirmation(kind: RemoteControlCommandKind) -> RemoteDangerConfirmationChallenge? {
        guard isEnabled else {
            return nil
        }

        return sessionStore.issueDangerConfirmation(
            nonce: UUID().uuidString,
            commandKind: kind,
            now: commandContextProvider().now,
            ttl: 5
        )
    }

    private func executeAcceptedCommand(
        _ command: RemoteControlAcceptedCommand
    ) -> RemoteControlCommandExecutionResult {
        guard sessionStore.markCommandIDIfNew(command.id) else {
            return .rejected(.duplicateCommandID)
        }
        if let nonce = command.dangerConfirmationNonce,
           !sessionStore.consumeDangerConfirmation(nonce: nonce, now: commandContextProvider().now) {
            return .rejected(.consumedDangerConfirmation)
        }
        return commandExecutor(command)
    }

    private func closeSessionAfterResponse() {
        guard isEnabled else {
            return
        }

        disable()
        sessionCloseObserver()
    }

    private static func disabledCommandContext() -> RemoteControlCommandValidationContext {
        RemoteControlCommandValidationContext(
            isRemoteEnabled: false,
            acceptedCommandIDs: [],
            dangerConfirmationChallenges: [:],
            now: Date()
        )
    }

    private func fail(reason: String) -> RemoteControlServerEnableResult {
        listener = nil
        activeEndpoint = nil
        sessionStore.disable()
        lastFailureReason = reason
        return .failed(RemoteControlServerFailure(reason: reason))
    }

    private func resolvedEndpointPort(listenerPort: UInt16?, requestedPort: UInt16?) -> UInt16 {
        guard let listenerPort, listenerPort != 0 else {
            return requestedPort ?? 0
        }
        return listenerPort
    }

    private func handleListenerFailure() {
        listener?.cancel()
        listener = nil
        activeEndpoint = nil
        sessionStore.disable()
        lastFailureReason = "listenerFailed"
    }
}

private final class RemoteControlNWListener: RemoteControlListening {
    private let listener: NWListener
    private let queue = DispatchQueue(label: "LiveSwitcher.RemoteControlServer")
    var requestHandler: ((String) -> Data)?
    var failureHandler: (() -> Void)?

    var port: UInt16? {
        listener.port?.rawValue
    }

    init(port: UInt16?) throws {
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        let listenerPort: NWEndpoint.Port
        if let port {
            guard let requestedPort = NWEndpoint.Port(rawValue: port) else {
                throw RemoteControlNWListenerError.invalidPort
            }
            listenerPort = requestedPort
        } else {
            listenerPort = .any
        }
        listener = try NWListener(using: parameters, on: listenerPort)
    }

    func start() throws {
        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection)
        }
        listener.stateUpdateHandler = { [weak self] state in
            if case .failed = state {
                self?.failureHandler?()
            }
        }
        listener.start(queue: queue)
    }

    func cancel() {
        listener.cancel()
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, _, _ in
            let responseData = self?.responseData(for: data) ?? RemoteControlHTTPWireCodec.serialize(.json(
                statusCode: 500,
                [("error", "serverUnavailable")]
            ))
            connection.send(content: responseData, completion: .contentProcessed { _ in
                connection.cancel()
            })
        }
    }

    private func responseData(for data: Data?) -> Data {
        guard let data,
              let rawRequest = String(data: data, encoding: .utf8),
              let requestHandler else {
            return RemoteControlHTTPWireCodec.serialize(.json(
                statusCode: 400,
                [("error", "invalidRequest")]
            ))
        }

        return requestHandler(rawRequest)
    }
}

private enum RemoteControlNWListenerError: Error {
    case invalidPort
}

enum RemoteControlHTTPWireCodec {
    static func serialize(_ response: RemoteControlHTTPResponse) -> Data {
        var lines = [
            "HTTP/1.1 \(response.statusCode) \(reasonPhrase(for: response.statusCode))",
            "Content-Length: \(response.body.count)",
            "Connection: close"
        ]
        lines.append(contentsOf: response.headers
            .sorted { $0.key < $1.key }
            .map { "\($0.key): \($0.value)" })

        var data = Data(lines.joined(separator: "\r\n").utf8)
        data.append(Data("\r\n\r\n".utf8))
        data.append(response.body)
        return data
    }

    private static func reasonPhrase(for statusCode: Int) -> String {
        switch statusCode {
        case 200:
            return "OK"
        case 202:
            return "Accepted"
        case 400:
            return "Bad Request"
        case 401:
            return "Unauthorized"
        case 403:
            return "Forbidden"
        case 404:
            return "Not Found"
        case 405:
            return "Method Not Allowed"
        case 409:
            return "Conflict"
        default:
            return "Internal Server Error"
        }
    }
}
