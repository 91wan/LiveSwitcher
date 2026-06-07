import AppKit

@MainActor
extension SwitcherViewModel {
    func switchToProgram(_ item: ProgramItem) {
        guard programSourceIsAvailable(item) else { return }
        guard let plan = ProgramActivationPlanner.plan(
            item: item,
            currentItem: currentProgramItem,
            queuedItems: programItems,
            isValidDeckDocument: { [weak self] url, kind in
                self?.isLikelyValidDeckDocument(url: url, sourceKind: kind) ?? false
            }
        ) else {
            return
        }

        executeProgramActivationPlan(plan)
    }

    func switchToProgramAfterReadinessConfirmation(_ item: ProgramItem) {
        let readiness = PresentationReadinessProbe.probe(item: item)
        guard readiness.severity == .blocked else {
            switchToProgram(item)
            return
        }

        let alert = NSAlert()
        alert.messageText = "Presentation is not ready"
        alert.informativeText = "\(readiness.operatorMessage)\n\nContinue anyway?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Continue")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        switchToProgram(item)
    }

    func switchToProgram(at index: Int) {
        guard index >= 0 && index < programItems.count else { return }
        switchToProgram(programItems[index])
    }

    /// Fix Issue #4: 空格键 - 暂停/继续（也处理 Keynote 播放状态）
    func toggleMainVideoPlayback() {
        guard let item = currentProgramItem else { return }

        switch item.sourceKind {
        case .activeDeck, .keynote, .pptx:
            actionHandlers.deckStop()
            return
        case .html, .agendaMarker, .unsupported:
            return
        case .media:
            break
        }

        guard !isPanicMode else {
            if runtime.state.media.isPlaying || avCoordinator.isPlaying {
                dispatchRuntimeFacadeAction(.operatorPausedMediaForPanic(generation: nil))
                if panicPlaybackSnapshot?.currentProgramID == item.id {
                    panicPlaybackSnapshot?.wasMediaPlaying = false
                }
            }
            return
        }

        // 普通视频
        dispatchRuntimeFacadeAction(.operatorToggledMediaPlayback)
    }

    func togglePause(for item: ProgramItem) {
        guard currentProgramItem?.id == item.id else {
            switchToProgram(item)
            return
        }
        toggleMainVideoPlayback()
    }

    func seekProgramItemToStart(_ item: ProgramItem) {
        if currentProgramItem?.id == item.id && programItemSupportsSeeking(item) {
            dispatchRuntimeFacadeAction(.operatorSeekedCurrentMediaToStart)
        }
    }

    func restartCurrentMediaFromBeginning() {
        guard let item = currentProgramItem,
              programItemSupportsSeeking(item) else { return }
        dispatchRuntimeFacadeAction(.operatorRestartedCurrentMedia)
        recordSupportEvent(kind: .mediaRestarted, detail: "source=current")
    }

    func seekProgramItemToEnd(_ item: ProgramItem) {
        if currentProgramItem?.id == item.id && programItemSupportsSeeking(item) {
            dispatchRuntimeFacadeAction(.operatorSeekedCurrentMediaToEnd)
        }
    }

    func confirmAgendaAutoAdvance(_ prompt: AgendaAutoAdvancePrompt) {
        agendaAutoAdvancePromptedItemIDs.insert(prompt.itemID)
        guard let item = programItems.first(where: { $0.id == prompt.itemID }) else { return }
        switchToProgramAfterReadinessConfirmation(item)
    }

    private func executeProgramActivationPlan(_ plan: ProgramActivationPlan) {
        if case .invalidDeck(let url) = plan.sideEffect {
            actionHandlers.invalidDeck(url)
            return
        }

        if plan.shouldStopCurrentDeckPresentation {
            actionHandlers.deckStop()
        }

        dispatchRuntimeProgramSelection(plan.runtimeSelection)
        setCurrentProgramFromOperatorSelection(plan.item)

        if plan.shouldClearHTML {
            currentHTMLURL = nil
        }

        switch plan.sideEffect {
        case .none:
            needsMutedMediaStartupAfterClearedProgram = false
        case .presentKeynote(let url):
            actionHandlers.keynotePresentation(url)
        case .openPPTX(let url):
            actionHandlers.pptxOpen(url)
        case .openHTML(let url):
            openHTMLInOutputWindow(url: url)
        case .presentActiveDeck:
            actionHandlers.activeDeckPresentation()
        case .invalidDeck:
            break
        }
    }

    private func setCurrentProgramFromOperatorSelection(_ item: ProgramItem?) {
        suppressCurrentProgramFacadeDispatch = true
        defer { suppressCurrentProgramFacadeDispatch = false }
        currentProgramItem = item
    }

    private func dispatchRuntimeProgramSelection(_ selection: ProgramActivationPlan.RuntimeSelection) {
        switch selection {
        case .queued(let id):
            dispatchRuntimeFacadeAction(.operatorSelectedProgram(id))
        case .detached(let item):
            dispatchRuntimeFacadeAction(.operatorSelectedDetachedProgram(item))
        }
    }

    private func programSourceIsAvailable(_ item: ProgramItem) -> Bool {
        switch programSourceAvailabilityKind(for: item) {
        case .media, .html, .keynote, .pptx:
            guard let url = item.sourceURL else {
                handleUnavailableProgramSource(item, reason: "sourceURLMissing")
                return false
            }
            guard FileManager.default.fileExists(atPath: url.path) else {
                handleUnavailableProgramSource(item, reason: "fileMissing")
                return false
            }
            return true
        case .activeDeck, .agendaMarker, .unsupported:
            return true
        }
    }

    private func handleUnavailableProgramSource(_ item: ProgramItem, reason: String) {
        recordSupportEvent(
            kind: .programItemFileMissing,
            detail: "sourceKind=\(programSourceKindSupportLabel(programSourceAvailabilityKind(for: item))),reason=\(reason)"
        )
        showAutomationRuntimeNotice(action: "program.source.missing")
    }

    private func programSourceAvailabilityKind(for item: ProgramItem) -> ProgramSourceKind {
        if item.sourceURL != nil || item.isAgendaMarker || item.sourceKind == .activeDeck {
            return item.sourceKind
        }

        let label = item.subtitle.uppercased()
        if label.contains("VIDEO") || label.contains("AUDIO") || label.contains("MEDIA") {
            return .media
        }
        if label.contains("HTML") {
            return .html
        }
        if label.contains("PPT") {
            return .pptx
        }
        return item.sourceKind
    }

    private func programSourceKindSupportLabel(_ kind: ProgramSourceKind) -> String {
        switch kind {
        case .media:
            return "media"
        case .html:
            return "html"
        case .keynote:
            return "keynote"
        case .pptx:
            return "pptx"
        case .activeDeck:
            return "activeDeck"
        case .agendaMarker:
            return "agendaMarker"
        case .unsupported:
            return "unsupported"
        }
    }

    private func programItemSupportsSeeking(_ item: ProgramItem) -> Bool {
        item.sourceKind.supportsSeeking
    }
}
