import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class RemoteControlSetupController {
    var state: RemoteControlSetupState = .disabled
    @ObservationIgnored var listenerFactory: RemoteControlServer.ListenerFactory?
    @ObservationIgnored var tokenProvider: () throws -> RemoteControlToken = {
        try RemoteControlTokenPolicy.makeToken()
    }
    @ObservationIgnored var localAddressProvider: () -> String? = {
        RemoteControlNetworkAddress.localIPv4Address()
    }
    @ObservationIgnored var portProvider: () -> UInt16? = {
        RemoteControlPortPolicy.makeSessionPort()
    }
    @ObservationIgnored private var server: RemoteControlServer?

    deinit {
        server?.disable()
    }

    func enable() {
        disable()

        guard let host = localAddressProvider() else {
            state = RemoteControlSetupState(status: .failed, host: nil, port: nil, pairingURL: nil)
            return
        }

        let remoteServer = makeServer()
        switch remoteServer.enable(port: portProvider()) {
        case .started(let endpoint):
            server = remoteServer
            state = RemoteControlSetupState(
                status: .enabled,
                host: host,
                port: endpoint.port,
                pairingURL: RemoteControlPairingURLBuilder.pairingURL(host: host, endpoint: endpoint)
            )
        case .failed:
            server = nil
            state = RemoteControlSetupState(status: .failed, host: nil, port: nil, pairingURL: nil)
        }
    }

    func disable() {
        server?.disable()
        server = nil
        state = .disabled
    }

    func copyPairingURL() {
        guard let pairingURL = state.pairingURL else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(pairingURL, forType: .string)
    }

    private func makeServer() -> RemoteControlServer {
        if let listenerFactory {
            return RemoteControlServer(
                listenerFactory: listenerFactory,
                tokenProvider: tokenProvider,
                snapshotProvider: { RemoteControlSnapshot.remoteSetupPlaceholder },
                commandContextProvider: Self.commandContextBeforeExecutionBridge
            )
        }

        return RemoteControlServer(
            tokenProvider: tokenProvider,
            snapshotProvider: { RemoteControlSnapshot.remoteSetupPlaceholder },
            commandContextProvider: Self.commandContextBeforeExecutionBridge
        )
    }

    private static func commandContextBeforeExecutionBridge() -> RemoteControlCommandValidationContext {
        RemoteControlCommandValidationContext(
            isRemoteEnabled: false,
            acceptedCommandIDs: [],
            dangerConfirmationExpirations: [:],
            now: Date()
        )
    }
}

private extension RemoteControlSnapshot {
    static var remoteSetupPlaceholder: RemoteControlSnapshot {
        RemoteControlSnapshot(
            connectionState: .enabled,
            currentProgramTitle: nil,
            nextProgramTitle: nil,
            isBroadcasting: false,
            isPanicActive: false,
            isFadeToBlackActive: false,
            isCurrentMediaPlaying: false,
            canToggleCurrentMedia: false,
            canReturnCurrentMediaToStart: false,
            currentBGMTitle: nil,
            isBGMPlaying: false,
            canSelectPreviousBGM: false,
            canSelectNextBGM: false,
            isSpeakerMode: false,
            disabledReason: nil
        )
    }
}
