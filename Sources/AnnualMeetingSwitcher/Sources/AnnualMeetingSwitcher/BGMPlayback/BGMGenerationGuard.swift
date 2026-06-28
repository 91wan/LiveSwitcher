@MainActor
extension SwitcherViewModel {
    func isCurrentRuntimeBGMGeneration(_ generation: Int) -> Bool {
        runtime.state.bgm.generation == generation
    }
}
