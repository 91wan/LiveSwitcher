import Foundation

@MainActor
extension SwitcherViewModel {
    func clearCurrentProgramSelection(reason: ProgramSelectionClearReason) {
        if runtime.bridgeMode.owns(.programSelection) {
            dispatchRuntimeFacadeAction(.operatorClearedCurrentProgram(reason: reason))
        } else {
            applyCurrentProgramProjectionFromRuntime(nil, switchedAt: nil)
        }
    }
}
