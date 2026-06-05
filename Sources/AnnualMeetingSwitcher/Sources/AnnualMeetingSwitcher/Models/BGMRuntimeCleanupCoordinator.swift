import Foundation

protocol BGMRuntimeCleanupHandle: AnyObject {
    var volume: Float { get set }
    func stop()
    func pause()
    func clear()
}

@MainActor
final class BGMRuntimeCleanupCoordinator {
    var currentGeneration = 0
    weak var currentPlayer: BGMRuntimeCleanupHandle?
    weak var currentFallbackPlayer: BGMRuntimeCleanupHandle?
    private var retiredFallbacks: [UUID: BGMRuntimeCleanupHandle] = [:]

    func fadeCurrentPlayerVolume(to targetVolume: Float, generation: Int) {
        guard currentGeneration == generation else { return }
        currentPlayer?.volume = targetVolume
    }

    func fadeRetiredPlayerVolume(_ player: BGMRuntimeCleanupHandle, to targetVolume: Float) {
        player.volume = targetVolume
    }

    func releaseRetiredPlayer(_ player: BGMRuntimeCleanupHandle) {
        player.stop()
    }

    func trackRetiredFallback(_ player: BGMRuntimeCleanupHandle) -> UUID {
        let token = UUID()
        retiredFallbacks[token] = player
        return token
    }

    func hasRetiredFallback(_ token: UUID) -> Bool {
        retiredFallbacks[token] != nil
    }

    func cleanupRetiredFallback(_ player: BGMRuntimeCleanupHandle, token: UUID) {
        player.volume = 0
        player.pause()
        player.clear()
        retiredFallbacks[token] = nil
    }
}
