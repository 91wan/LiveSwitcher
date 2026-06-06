import AppKit

@MainActor
extension SwitcherViewModel {
    // MARK: - 节目操作

    func switchToProgram(_ item: ProgramItem) {
        guard programSourceIsAvailable(item) else { return }
        guard item.sourceKind.isActivatableProgram else { return }

        switch item.sourceKind {
        case .agendaMarker, .unsupported:
            return
        case .media:
            stopCurrentDeckPresentationIfNeeded(before: item)
            dispatchRuntimeProgramSelection(for: item)
            currentHTMLURL = nil              // 清空 HTML 层
            needsMutedMediaStartupAfterClearedProgram = false
            setCurrentProgramFromOperatorSelection(item)
        case .keynote:
            guard let url = item.sourceURL else { return }
            if !isLikelyValidDeckDocument(url: url, sourceKind: .keynote) {
                actionHandlers.invalidDeck(url)
                return
            }
            stopCurrentDeckPresentationIfNeeded(before: item)
            dispatchRuntimeProgramSelection(for: item)
            setCurrentProgramFromOperatorSelection(item)
            currentHTMLURL = nil              // 清空 HTML 层
            actionHandlers.keynotePresentation(url)
        case .pptx:
            guard let url = item.sourceURL else { return }
            if !isLikelyValidDeckDocument(url: url, sourceKind: .pptx) {
                actionHandlers.invalidDeck(url)
                return
            }
            stopCurrentDeckPresentationIfNeeded(before: item)
            dispatchRuntimeProgramSelection(for: item)
            setCurrentProgramFromOperatorSelection(item)
            currentHTMLURL = nil              // 清空 HTML 层
            actionHandlers.pptxOpen(url)
        case .html:
            guard let url = item.sourceURL else { return }
            stopCurrentDeckPresentationIfNeeded(before: item)
            dispatchRuntimeProgramSelection(for: item)
            setCurrentProgramFromOperatorSelection(item)
            openHTMLInOutputWindow(url: url)
        case .activeDeck:
            stopCurrentDeckPresentationIfNeeded(before: item)
            dispatchRuntimeProgramSelection(for: item)
            setCurrentProgramFromOperatorSelection(item)
            currentHTMLURL = nil
            actionHandlers.activeDeckPresentation()
        }
    }

    private func setCurrentProgramFromOperatorSelection(_ item: ProgramItem?) {
        suppressCurrentProgramFacadeDispatch = true
        defer { suppressCurrentProgramFacadeDispatch = false }
        currentProgramItem = item
    }

    private func dispatchRuntimeProgramSelection(for item: ProgramItem) {
        if programItems.contains(where: { $0.id == item.id }) {
            dispatchRuntimeFacadeAction(.operatorSelectedProgram(item.id))
        } else {
            dispatchRuntimeFacadeAction(.operatorSelectedDetachedProgram(item))
        }
    }

    private func stopCurrentDeckPresentationIfNeeded(before nextItem: ProgramItem) {
        guard let currentProgramItem,
              currentProgramItem.id != nextItem.id,
              currentProgramItem.supportsPresentationControl
        else { return }
        actionHandlers.deckStop()
    }

    private func programSourceIsAvailable(_ item: ProgramItem) -> Bool {
        switch item.sourceKind {
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
            detail: "sourceKind=\(programSourceKindSupportLabel(item.sourceKind)),reason=\(reason)"
        )
        showAutomationRuntimeNotice(action: "program.source.missing")
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

    func addProgramItem(_ item: ProgramItem) {
        addProgramItems([item])
    }

    func addProgramItems(_ items: [ProgramItem]) {
        guard !items.isEmpty else { return }
        dispatchRuntimeFacadeAction(.operatorAddedProgramItems(items))
        saveData()
    }

    func addAgendaMarker(title: String = "Break") {
        dispatchRuntimeFacadeAction(.operatorAddedAgendaMarker(title: title))
        saveData()
    }

    func updateProgramItemSchedule(
        id: UUID,
        scheduledStartAt: Date?,
        scheduledDuration: TimeInterval?
    ) {
        dispatchRuntimeFacadeAction(.operatorUpdatedProgramItemSchedule(
            id: id,
            scheduledStartAt: scheduledStartAt,
            scheduledDuration: scheduledDuration
        ))
        if currentProgramItem?.id == id {
            if let updatedItem = programItems.first(where: { $0.id == id }) {
                currentProgramItem = updatedItem
            }
        }
        agendaAutoAdvancePromptedItemIDs.remove(id)
        saveData()
    }

    func removeProgramItem(withID id: UUID) {
        let removedItem = programItems.first { $0.id == id }
        let isCurrent = currentProgramItem?.id == id
        if isCurrent {
            needsMutedMediaStartupAfterClearedProgram = removedItem?.sourceKind == .media
            if removedItem?.supportsPresentationControl == true {
                actionHandlers.deckStop()
            }
            if removedItem?.sourceKind == .media {
                dispatchRuntimeFacadeAction(.operatorStoppedCurrentMedia)
            }
            currentProgramItem = nil
            currentHTMLURL = nil   // Bug2修复：删除HTML条目时清空大屏
        }
        dispatchRuntimeFacadeAction(.operatorRemovedProgramItem(id))
        saveData()
    }

    func moveProgramItems(from source: IndexSet, to destination: Int) {
        dispatchRuntimeFacadeAction(.operatorMovedProgramItems(
            fromOffsets: Array(source),
            toOffset: destination
        ))
        saveData()
    }

    func agendaAutoAdvancePrompt(now: Date = Date()) -> AgendaAutoAdvancePrompt? {
        AgendaAutoAdvanceModel.prompt(
            isEnabled: autoAdvanceAtScheduledTime,
            programItems: programItems,
            currentProgramItem: currentProgramItem,
            now: now,
            promptedItemIDs: agendaAutoAdvancePromptedItemIDs
        )
    }

    func dismissAgendaAutoAdvancePrompt(_ prompt: AgendaAutoAdvancePrompt) {
        agendaAutoAdvancePromptedItemIDs.insert(prompt.itemID)
    }

    func confirmAgendaAutoAdvance(_ prompt: AgendaAutoAdvancePrompt) {
        agendaAutoAdvancePromptedItemIDs.insert(prompt.itemID)
        guard let item = programItems.first(where: { $0.id == prompt.itemID }) else { return }
        switchToProgramAfterReadinessConfirmation(item)
    }

    private func programItemSupportsSeeking(_ item: ProgramItem) -> Bool {
        item.sourceKind.supportsSeeking
    }
}
