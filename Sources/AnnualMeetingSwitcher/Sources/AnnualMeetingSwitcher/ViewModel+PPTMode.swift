import Foundation

@MainActor
extension SwitcherViewModel {
    func togglePPTMode(source: PPTModeToggleSource = .programmatic) {
        dispatchPPTIntent(.operatorToggledPPTMode(source: source), source: source)
    }

    func setPPTMode(_ enabled: Bool, source: PPTModeToggleSource = .programmatic) {
        dispatchPPTIntent(.operatorSetPPTMode(enabled, source: source), source: source)
    }

    private func dispatchPPTIntent(_ action: LiveRuntimeAction, source: PPTModeToggleSource) {
        let previousPPT = runtime.state.ppt
        setPendingPPTToggleSource(source)
        dispatchRuntimeFacadeAction(action)
        if runtime.state.ppt == previousPPT {
            setPendingPPTToggleSource(nil)
        }
    }
}
