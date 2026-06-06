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
            cornerLogoImage = nil
            return
        }
        cornerLogoImage = NSImage(byReferencing: url)
        cleanupBag.cornerLogoImageLoadTask = Task { @MainActor [weak self] in
            let data = await Self.imageData(from: url)
            guard !Task.isCancelled, let self, self.cornerLogoURL == url else { return }
            self.cornerLogoImage = data.flatMap(NSImage.init(data:))
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
        guard WallpaperImagePolicy.isRenderableImage(url: url) else { return false }
        cornerLogoURL = url
        saveData()
        return true
    }

    func removeCornerLogo() {
        cornerLogoURL = nil
        saveData()
    }
}
