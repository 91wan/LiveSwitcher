import Foundation

@MainActor
extension SwitcherViewModel {
    func configureDefaultActionHandlers() {
        actionHandlers.keynotePresentation = { [weak self] url in
            self?.openAndPresentKeynote(url: url)
        }
        actionHandlers.pptxOpen = { [weak self] url in
            self?.openPPTXWithKeynote(url: url)
        }
        actionHandlers.deckStop = { [weak self] in
            self?.stopDeckPresentation()
        }
        actionHandlers.programSeekToStart = { [weak self] in
            self?.avCoordinator.seekToBeginning()
        }
        actionHandlers.programRestartFromBeginning = { [weak self] onReadyToPlay in
            self?.avCoordinator.restartFromBeginning(onReadyToPlay: onReadyToPlay)
        }
        actionHandlers.programSeekToEnd = { [weak self] in
            self?.avCoordinator.seekToEnd()
        }
        actionHandlers.activeDeckPresentation = { [weak self] in
            self?.presentFrontKeynoteDocument()
        }
        actionHandlers.invalidDeck = { [weak self] url in
            self?.presentInvalidDeckAlert(for: url)
        }
    }
}
