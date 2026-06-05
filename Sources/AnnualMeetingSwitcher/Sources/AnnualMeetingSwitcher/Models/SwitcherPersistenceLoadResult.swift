import Foundation

struct SwitcherPersistenceLoadResult {
    var state: SwitcherPersistentState
    var supportEvents: [LiveSupportEvent]
    var repairedWallpaperPaths: [String]?
    var repairedActiveWallpaperURL: URL?
    var shouldRewriteWallpaperPaths: Bool

    init(
        state: SwitcherPersistentState = SwitcherPersistentState(),
        supportEvents: [LiveSupportEvent] = [],
        repairedWallpaperPaths: [String]? = nil,
        repairedActiveWallpaperURL: URL? = nil,
        shouldRewriteWallpaperPaths: Bool = false
    ) {
        self.state = state
        self.supportEvents = supportEvents
        self.repairedWallpaperPaths = repairedWallpaperPaths
        self.repairedActiveWallpaperURL = repairedActiveWallpaperURL
        self.shouldRewriteWallpaperPaths = shouldRewriteWallpaperPaths
    }
}
