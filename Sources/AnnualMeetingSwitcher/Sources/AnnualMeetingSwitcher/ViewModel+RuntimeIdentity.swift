import Foundation

@MainActor
extension SwitcherViewModel {
    func setActiveRuntimeMediaCallbackIdentity(generation: Int, url: URL) {
        runtimeIdentityStore.setActiveMedia(generation: generation, url: url)
    }

    func clearActiveRuntimeMediaCallbackIdentity(ifGeneration generation: Int) {
        runtimeIdentityStore.clearActiveMedia(ifGeneration: generation)
    }

    func validatedRuntimeMediaCallbackGeneration() -> Int? {
        runtimeIdentityStore.validatedMediaGeneration(
            runtimeGeneration: runtimeBackedMediaGenerationForCallbackValidation,
            currentProgram: runtimeBackedCurrentProgramForMediaCallbackValidation,
            currentMediaURL: avCoordinator.currentURL
        )
    }

    private var runtimeBackedCurrentProgramForMediaCallbackValidation: ProgramItem? {
        runtime.bridgeMode.owns(.programSelection)
            ? runtime.state.program.effectiveCurrentItem
            : currentProgramItem
    }

    private var runtimeBackedMediaGenerationForCallbackValidation: Int? {
        runtime.bridgeMode.owns(.media)
            ? runtime.state.media.generation
            : nil
    }

    func setActiveRuntimeBGMCallbackIdentity(item: BGMItem, generation: Int) {
        runtimeIdentityStore.setActiveBGM(item: item, generation: generation)
    }

    func clearActiveRuntimeBGMCallbackIdentity() {
        runtimeIdentityStore.clearActiveBGM()
    }

    func validatedRuntimeBGMCallbackGeneration() -> Int? {
        runtimeIdentityStore.validatedBGMGeneration(
            runtimeGeneration: runtimeBackedBGMGenerationForCallbackValidation,
            currentItem: runtimeBackedCurrentBGMItemForCallbackValidation
        )
    }

    private var runtimeBackedCurrentBGMItemForCallbackValidation: BGMItem? {
        runtime.bridgeMode.owns(.bgm)
            ? runtime.state.bgm.currentItem
            : currentBGMItem
    }

    private var runtimeBackedBGMGenerationForCallbackValidation: Int? {
        runtime.bridgeMode.owns(.bgm)
            ? runtime.state.bgm.generation
            : nil
    }

    func includeTransientRuntimeBGMItem(_ item: BGMItem) {
        runtimeIdentityStore.includeTransientBGMItem(item)
    }

    func clearTransientRuntimeBGMItemIfNeeded(_ item: BGMItem) {
        runtimeIdentityStore.clearTransientBGMItemIfNeeded(item)
    }

    func runtimeBGMItemsForSnapshot() -> [BGMItem] {
        runtimeIdentityStore.runtimeBGMItems(
            libraryItems: bgmItems,
            runtimeCurrentItem: runtime.bridgeMode.owns(.bgm) ? runtime.state.bgm.currentItem : nil,
            facadeCurrentItem: currentBGMItem
        )
    }
}
