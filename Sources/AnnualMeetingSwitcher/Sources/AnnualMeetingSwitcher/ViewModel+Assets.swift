import AppKit
import Foundation

extension SwitcherViewModel {
    func loadBackgroundImage(from url: URL?) {
        cleanupBag.backgroundImageLoadTask?.cancel()
        guard let url else {
            backgroundImage = nil
            return
        }
        backgroundImage = NSImage(byReferencing: url)
        cleanupBag.backgroundImageLoadTask = Task { @MainActor [weak self] in
            let data = await Self.imageData(from: url)
            guard !Task.isCancelled, let self, self.activeWallpaperURL == url else { return }
            self.backgroundImage = data.flatMap(NSImage.init(data:))
        }
    }

    func loadCornerLogoImage(from url: URL?) {
        cleanupBag.cornerLogoImageLoadTask?.cancel()
        guard let url else {
            isCornerLogoVisible = false
            cornerLogoImage = nil
            cornerLogoLoadPhase = .empty
            return
        }

        if case .ready(let activeURL) = cornerLogoLoadPhase,
           activeURL == url,
           cornerLogoImage != nil {
            return
        }

        startCornerLogoCandidateLoad(url: url, saveOnSuccess: false)
    }

    static func defaultCornerLogoImageLoader(_ url: URL) async -> Result<NSImage, CornerLogoLoadFailure> {
        guard let data = await imageData(from: url),
              let image = NSImage(data: data),
              image.size.width > 0,
              image.size.height > 0
        else {
            return .failure(.decodeFailed)
        }
        return .success(image)
    }

    private func startCornerLogoCandidateLoad(url: URL, saveOnSuccess: Bool) {
        cleanupBag.cornerLogoImageLoadTask?.cancel()
        let requestID = UUID()
        cornerLogoLoadPhase = .loading(candidateURL: url, requestID: requestID)
        cleanupBag.cornerLogoImageLoadTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let result = await self.cornerLogoImageLoader(url)
            guard !Task.isCancelled else { return }
            self.completeCornerLogoCandidateLoad(
                url: url,
                requestID: requestID,
                result: result,
                saveOnSuccess: saveOnSuccess
            )
        }
    }

    private func completeCornerLogoCandidateLoad(
        url: URL,
        requestID: UUID,
        result: Result<NSImage, CornerLogoLoadFailure>,
        saveOnSuccess: Bool
    ) {
        guard case .loading(let candidateURL, let activeRequestID) = cornerLogoLoadPhase,
              candidateURL == url,
              activeRequestID == requestID
        else { return }

        switch result {
        case .success(let image):
            let hadCommittedLogo = cornerLogoURL != nil
            cornerLogoImage = image
            cornerLogoLoadPhase = .ready(activeURL: url)
            if cornerLogoURL != url {
                cornerLogoURL = url
            }
            if !hadCommittedLogo {
                isCornerLogoVisible = true
            }
            if saveOnSuccess {
                saveData()
            }
        case .failure(let reason):
            cornerLogoLoadPhase = .failed(candidateURL: url, reason: reason)
        }
    }

    nonisolated private static func imageData(from url: URL) async -> Data? {
        await Task.detached(priority: .utility) {
            try? Data(contentsOf: url)
        }.value
    }

    @discardableResult
    func addWallpaper(url: URL) -> Bool {
        guard WallpaperImagePolicy.isRenderableImage(url: url) else { return false }
        guard !backgroundWallpapers.contains(url) else { return true }
        backgroundWallpapers.append(url)
        saveData()
        return true
    }

    func removeWallpaper(url: URL) {
        backgroundWallpapers.removeAll { $0 == url }
        if activeWallpaperURL == url {
            activeWallpaperURL = backgroundWallpapers.first
        }
        saveData()
    }

    func setActiveWallpaper(url: URL) {
        guard backgroundWallpapers.contains(url) else { return }
        activeWallpaperURL = url
        saveData()
    }

    @discardableResult
    func setCornerLogo(url: URL) -> Bool {
        guard WallpaperImagePolicy.isSupported(url: url) else {
            cornerLogoLoadPhase = .failed(candidateURL: url, reason: .unsupportedFile)
            return false
        }
        startCornerLogoCandidateLoad(url: url, saveOnSuccess: true)
        return true
    }

    func removeCornerLogo() {
        cleanupBag.cornerLogoImageLoadTask?.cancel()
        isCornerLogoVisible = false
        cornerLogoURL = nil
        cornerLogoImage = nil
        cornerLogoLoadPhase = .empty
        saveData()
    }

    func retryCornerLogoLoad() {
        guard case .failed(let candidateURL, _) = cornerLogoLoadPhase,
              let candidateURL else { return }
        startCornerLogoCandidateLoad(url: candidateURL, saveOnSuccess: cornerLogoURL != candidateURL)
    }
}
