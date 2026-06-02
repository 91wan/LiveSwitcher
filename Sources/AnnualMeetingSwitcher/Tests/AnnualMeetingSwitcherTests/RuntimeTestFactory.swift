import Foundation
@testable import LiveSwitcher

@MainActor
enum RuntimeTestFactory {
    static func audioOwnedStore(
        effectRunner: LiveRuntimeEffectRunner = .recording()
    ) -> LiveRuntimeStore {
        LiveRuntimeStore(
            effectRunner: effectRunner,
            environment: .productionAudioOwned()
        )
    }

    static func fullRuntimeStore(
        effectRunner: LiveRuntimeEffectRunner = .recording()
    ) -> LiveRuntimeStore {
        LiveRuntimeStore(
            effectRunner: effectRunner,
            environment: .fullRuntimeForTests()
        )
    }

    static func recordingOnlyStore(
        effectRunner: LiveRuntimeEffectRunner = .recording()
    ) -> LiveRuntimeStore {
        LiveRuntimeStore(
            effectRunner: effectRunner,
            environment: .recordingOnlyForTests()
        )
    }
}
