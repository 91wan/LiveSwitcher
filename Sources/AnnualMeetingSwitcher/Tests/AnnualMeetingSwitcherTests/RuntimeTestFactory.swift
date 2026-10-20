import Foundation
@testable import LiveSwitcher

@MainActor
enum RuntimeTestFactory {
    static func fullRuntimeStore(
        effectRunner: LiveRuntimeEffectRunner = .recording()
    ) -> LiveRuntimeStore {
        LiveRuntimeStore(
            effectRunner: effectRunner,
            environment: .fullRuntimeForTests()
        )
    }
}
