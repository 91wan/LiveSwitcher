import Foundation

@MainActor
extension SwitcherViewModel {
    func configureDefaultProgramActivationSideEffects() {
        programActivationSideEffects.presentKeynote = { [weak self] url in
            self?.openAndPresentKeynote(url: url)
        }
        programActivationSideEffects.openPPTX = { [weak self] url in
            self?.openPPTXWithKeynote(url: url)
        }
        programActivationSideEffects.stopDeck = { [weak self] in
            self?.stopDeckPresentation()
        }
        programActivationSideEffects.presentActiveDeck = { [weak self] in
            self?.presentFrontKeynoteDocument()
        }
        programActivationSideEffects.presentInvalidDeckAlert = { [weak self] url in
            self?.presentInvalidDeckAlert(for: url)
        }
    }
}
