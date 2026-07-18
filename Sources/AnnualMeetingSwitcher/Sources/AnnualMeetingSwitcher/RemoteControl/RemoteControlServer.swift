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

@MainActor
final class RemoteControlServer {
    typealias ListenerFactory = (UInt16?) throws -> RemoteControlListening

    private let listenerFactory: ListenerFactory
    private let tokenProvider: () throws -> RemoteControlToken
    private let snapshotProvider: () -> RemoteControlSnapshot
    private let commandContextProvider: () -> RemoteControlCommandValidationContext
    private let commandExecutor: (RemoteControlAcceptedCommand) -> RemoteControlCommandExecutionResult
    private let sessionCloseObserver: () -> Void
    private var listener: RemoteControlListening?
    private var listenerGeneration: UUID?
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

    convenience init(
        localHost: String,
        tokenProvider: @escaping () throws -> RemoteControlToken = { try RemoteControlTokenPolicy.makeToken() },
        snapshotProvider: @escaping () -> RemoteControlSnapshot,
        commandContextProvider: @escaping () -> RemoteControlCommandValidationContext,
        sessionCloseObserver: @escaping () -> Void = {},
        commandExecutor: @escaping (RemoteControlAcceptedCommand) -> RemoteControlCommandExecutionResult = {
            .executed(RemoteControlCommandExecutionRecord(command: $0))
        }
    ) {
        self.init(
            listenerFactory: { try RemoteControlNWListener(port: $0, localHost: localHost) },
            tokenProvider: tokenProvider,
            snapshotProvider: snapshotProvider,
            commandContextProvider: commandContextProvider,
            sessionCloseObserver: sessionCloseObserver,
            commandExecutor: commandExecutor
        )
    }

    init(
        listenerFactory: @escaping ListenerFactory,
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
            let generation = UUID()
            newListener.requestHandler = makeRequestHandler(token: token)
            newListener.failureHandler = { [weak self] in
                RemoteControlMainActorExecutor.run {
                    self?.handleListenerFailure(generation: generation)
                }
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
            listenerGeneration = generation
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
        listenerGeneration = nil
        activeEndpoint = nil
        sessionStore.disable()
    }

    private func makeRequestHandler(token: RemoteControlToken) -> (String) -> Data {
        { [weak self] rawRequest in
            guard let request = RemoteControlHTTPParser.parse(rawRequest) else {
                return RemoteControlHTTPWireCodec.serialize(.json(
                    statusCode: 400,
                    [("error", "invalidRequest")]
                ))
            }

            // The listener queue may wait for MainActor; MainActor must never wait for the listener queue.
            return RemoteControlMainActorExecutor.run {
                guard let self else {
                    return RemoteControlHTTPWireCodec.serialize(.json(
                        statusCode: 403,
                        [("error", "invalidAuthorization")]
                    ))
                }
                return self.responseData(for: request, token: token)
            }
        }
    }

    private func responseData(
        for request: RemoteControlHTTPRequest,
        token: RemoteControlToken
    ) -> Data {
        guard acceptsRequest(request, token: token) else {
            return RemoteControlHTTPWireCodec.serialize(.json(
                statusCode: 403,
                [("error", "invalidAuthorization")]
            ))
        }

        var shouldCloseSession = false
        let router = RemoteControlRequestRouter(
            token: token,
            snapshotProvider: snapshotProvider,
            commandContextProvider: commandValidationContext,
            dangerConfirmationIssuer: issueDangerConfirmation,
            sessionCloseHandler: {
                guard self.isEnabled else {
                    return .remoteDisabled
                }
                shouldCloseSession = true
                return .closed
            },
            sessionClaimHandler: { clientID in
                self.sessionStore.claimController(clientID: clientID)
            },
            requiresControllerClientID: true,
            canExecuteCommandFromClient: { clientID in
                self.sessionStore.canExecuteCommand(from: clientID)
            },
            commandExecutor: executeAcceptedCommand
        )
        let data = RemoteControlHTTPWireCodec.serialize(router.route(request))
        if shouldCloseSession {
            closeSessionAfterResponse()
        }
        return data
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

    private func issueDangerConfirmation(
        kind: RemoteControlCommandKind,
        clientID: RemoteControlClientID?
    ) -> RemoteDangerConfirmationChallenge? {
        guard isEnabled else {
            return nil
        }

        return sessionStore.issueDangerConfirmation(
            nonce: UUID().uuidString,
            commandKind: kind,
            clientID: clientID,
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

    private func fail(reason: String) -> RemoteControlServerEnableResult {
        listener = nil
        listenerGeneration = nil
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

    private func handleListenerFailure(generation: UUID) {
        guard listenerGeneration == generation else {
            return
        }

        listener?.cancel()
        listener = nil
        listenerGeneration = nil
        activeEndpoint = nil
        sessionStore.disable()
        lastFailureReason = "listenerFailed"
    }
}

struct RemoteControlNWListenerConfiguration {
    let parameters: NWParameters
    let listenerPort: NWEndpoint.Port

    static func make(localHost: String, port: UInt16?) throws -> RemoteControlNWListenerConfiguration {
        // A bound listener needs a concrete port: requiredLocalEndpoint with port 0 (.any)
        // fails at listener start with EINVAL.
        guard let port, port != 0, let listenerPort = NWEndpoint.Port(rawValue: port) else {
            throw RemoteControlNWListenerError.invalidPort
        }

        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        parameters.requiredLocalEndpoint = .hostPort(
            host: NWEndpoint.Host(localHost),
            port: listenerPort
        )
        return RemoteControlNWListenerConfiguration(
            parameters: parameters,
            listenerPort: listenerPort
        )
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

    init(port: UInt16?, localHost: String) throws {
        let configuration = try RemoteControlNWListenerConfiguration.make(
            localHost: localHost,
            port: port
        )
        // NWListener(using:on:) rejects parameters that already carry a
        // requiredLocalEndpoint with EINVAL; the endpoint supplies the port.
        listener = try NWListener(using: configuration.parameters)
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
        receiveRequest(on: connection, accumulator: RemoteControlHTTPRequestAccumulator())
    }

    private func receiveRequest(
        on connection: NWConnection,
        accumulator: RemoteControlHTTPRequestAccumulator
    ) {
        var nextAccumulator = accumulator
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, isComplete, _ in
            guard let self else {
                connection.cancel()
                return
            }

            if let data, !data.isEmpty {
                switch nextAccumulator.append(data) {
                case .waiting:
                    break
                case .complete(let requestData):
                    self.sendResponse(for: .complete(requestData), on: connection)
                    return
                case .malformed:
                    self.sendResponse(for: .malformed, on: connection)
                    return
                case .oversized:
                    self.sendResponse(for: .oversized, on: connection)
                    return
                }
            }

            if isComplete {
                self.sendResponse(for: .malformed, on: connection)
                return
            }

            self.receiveRequest(on: connection, accumulator: nextAccumulator)
        }
    }

    private func sendResponse(for result: RemoteControlHTTPRequestReceiveResult, on connection: NWConnection) {
        let responseData = responseData(for: result)
        connection.send(content: responseData, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private func responseData(for result: RemoteControlHTTPRequestReceiveResult) -> Data {
        switch result {
        case .complete(let data):
            return responseData(forCompleteRequest: data)
        case .malformed:
            return RemoteControlHTTPWireCodec.serialize(.json(
                statusCode: 400,
                [("error", "invalidRequest")]
            ))
        case .oversized:
            return RemoteControlHTTPWireCodec.serialize(.json(
                statusCode: 413,
                [("error", "requestTooLarge")]
            ))
        }
    }

    private func responseData(forCompleteRequest data: Data) -> Data {
        guard
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

private enum RemoteControlHTTPRequestReceiveResult {
    case complete(Data)
    case malformed
    case oversized
}

enum RemoteControlHTTPRequestAccumulationResult: Equatable {
    case waiting
    case complete(Data)
    case malformed
    case oversized
}

struct RemoteControlHTTPRequestAccumulator {
    private static let headerTerminator = Data("\r\n\r\n".utf8)
    private var buffer = Data()
    private let maxByteCount: Int

    init(maxByteCount: Int = 65_536) {
        self.maxByteCount = maxByteCount
    }

    mutating func append(_ data: Data) -> RemoteControlHTTPRequestAccumulationResult {
        buffer.append(data)
        if buffer.count > maxByteCount {
            return .oversized
        }
        return completeRequestData()
    }

    private func completeRequestData() -> RemoteControlHTTPRequestAccumulationResult {
        guard let headerRange = buffer.range(of: Self.headerTerminator) else {
            return .waiting
        }

        let bodyStartIndex = headerRange.upperBound
        switch contentLength(in: buffer[..<headerRange.lowerBound]) {
        case .absent:
            return .complete(Data(buffer[..<bodyStartIndex]))
        case .malformed:
            return .malformed
        case .valid(let contentLength):
            guard bodyStartIndex <= maxByteCount,
                  contentLength <= maxByteCount - bodyStartIndex else {
                return .oversized
            }

            let expectedByteCount = bodyStartIndex + contentLength
            guard buffer.count >= expectedByteCount else {
                return .waiting
            }

            return .complete(Data(buffer[..<expectedByteCount]))
        }
    }

    private func contentLength(in headerData: Data.SubSequence) -> ContentLength {
        let headerText = String(decoding: headerData, as: UTF8.self)
        for line in headerText.components(separatedBy: "\r\n") {
            guard let separator = line.firstIndex(of: ":") else {
                continue
            }
            let key = line[..<separator].trimmingCharacters(in: .whitespacesAndNewlines)
            guard key.localizedCaseInsensitiveCompare("Content-Length") == .orderedSame else {
                continue
            }
            let value = line[line.index(after: separator)...].trimmingCharacters(in: .whitespacesAndNewlines)
            guard let length = Int(value), length >= 0 else {
                return .malformed
            }
            return .valid(length)
        }
        return .absent
    }

    private enum ContentLength {
        case absent
        case valid(Int)
        case malformed
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
        case 413:
            return "Payload Too Large"
        default:
            return "Internal Server Error"
        }
    }
}
