import Foundation

@MainActor
extension SwitcherViewModel {
    func configureRemoteControlCommandBridge() {
        remoteControlSetup.snapshotProvider = { [weak self] in
            RemoteControlMainActorExecutor.run {
                self?.remoteControlSnapshot() ?? .remoteSetupPlaceholder
            }
        }
        remoteControlSetup.commandExecutor = { [weak self] command in
            RemoteControlMainActorExecutor.run {
                guard let self else { return .rejected(.remoteDisabled) }
                return self.executeRemoteControlCommand(command)
            }
        }
    }

    func executeRemoteControlCommand(
        _ command: RemoteControlAcceptedCommand
    ) -> RemoteControlCommandExecutionResult {
        switch command.kind {
        case .takeNext:
            takeNextRemoteProgram()
        case .toggleCurrentMediaPlayback:
            toggleMainVideoPlayback()
        case .returnCurrentMediaToStart:
            returnCurrentMediaToStart()
        case .toggleBGMPlayback:
            toggleRemoteBGMPlayback()
        case .selectPreviousBGM:
            playPreviousBGM()
        case .selectNextBGM:
            playNextBGM()
        case .toggleSpeakerMode:
            toggleSpeakerMode()
        case .toggleFadeToBlack:
            toggleFadeToBlack()
        case .togglePanic:
            togglePanicMode()
        }

        return .executed(RemoteControlCommandExecutionRecord(command: command))
    }

    private func takeNextRemoteProgram() {
        guard let next = ProgramQueueStore.nextPlayableAfterCurrent(
            current: remoteControlCurrentProgram,
            in: remoteControlProgramItems
        ) else {
            return
        }
        switchToProgram(next)
    }

    private func toggleRemoteBGMPlayback() {
        guard let item = BGMDefaultSelectionPolicy.defaultItem(
            items: remoteControlBGMItems,
            currentItem: remoteControlCurrentBGMItem,
            selectedCategory: bgmLibraryCategorySelection.selectedCategory
        ) else {
            return
        }
        toggleBGM(item)
    }

    private func remoteControlSnapshot() -> RemoteControlSnapshot {
        let current = remoteControlCurrentProgram
        let next = ProgramQueueStore.nextPlayableAfterCurrent(
            current: current,
            in: remoteControlProgramItems
        )
        let currentBGM = remoteControlCurrentBGMItem

        return RemoteControlSnapshot(
            connectionState: remoteControlSetup.state.isEnabled ? .connected : .disabled,
            currentProgramTitle: current?.title,
            nextProgramTitle: next?.title,
            isBroadcasting: remoteControlIsBroadcasting,
            isPanicActive: remoteControlPanicIsActive,
            isFadeToBlackActive: isFadeToBlackActive,
            isCurrentMediaPlaying: remoteControlMediaIsPlaying,
            canToggleCurrentMedia: current?.sourceKind == .media,
            canReturnCurrentMediaToStart: current?.supportsSeeking == true,
            currentBGMTitle: currentBGM?.title,
            isBGMPlaying: remoteControlBGMIsPlaying,
            canSelectPreviousBGM: !remoteControlBGMItems.isEmpty,
            canSelectNextBGM: !remoteControlBGMItems.isEmpty,
            isSpeakerMode: remoteControlSpeakerModeIsActive,
            disabledReason: remoteControlSetup.state.isEnabled ? nil : "remoteDisabled"
        )
    }

    private var remoteControlProgramItems: [ProgramItem] {
        runtime.bridgeMode.owns(.programQueue)
            ? runtime.state.program.items
            : programItems
    }

    private var remoteControlCurrentProgram: ProgramItem? {
        runtime.bridgeMode.owns(.programSelection)
            ? runtime.state.program.effectiveCurrentItem
            : currentProgramItem
    }

    private var remoteControlBGMItems: [BGMItem] {
        runtime.bridgeMode.owns(.bgm)
            ? runtimeBGMItemsForSnapshot()
            : bgmItems
    }

    private var remoteControlCurrentBGMItem: BGMItem? {
        runtime.bridgeMode.owns(.bgm)
            ? runtime.state.bgm.currentItem
            : currentBGMItem
    }

    private var remoteControlBGMIsPlaying: Bool {
        runtime.bridgeMode.owns(.bgm)
            ? runtime.state.bgm.isPlaying
            : isBGMPlaying
    }

    private var remoteControlMediaIsPlaying: Bool {
        runtime.bridgeMode.owns(.media)
            ? runtime.state.media.isPlaying
            : avCoordinator.isPlaying
    }

    private var remoteControlPanicIsActive: Bool {
        runtime.bridgeMode.owns(.panic)
            ? runtime.state.panic.isActive
            : isPanicMode
    }

    private var remoteControlSpeakerModeIsActive: Bool {
        runtime.bridgeMode.owns(.audio)
            ? runtime.state.audio.isSpeakerMode
            : isSpeakerMode
    }

    private var remoteControlIsBroadcasting: Bool {
        runtime.bridgeMode.owns(.projection)
            ? runtime.state.projection.isBroadcasting
            : isBroadcasting
    }
}

enum RemoteControlMainActorExecutor {
    static func run<T>(_ operation: @MainActor () -> T) -> T {
        if Thread.isMainThread {
            return MainActor.assumeIsolated(operation)
        }

        return DispatchQueue.main.sync {
            MainActor.assumeIsolated(operation)
        }
    }
}
