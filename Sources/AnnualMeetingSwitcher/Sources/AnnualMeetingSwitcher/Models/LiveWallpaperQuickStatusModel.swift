import Foundation

struct LiveWallpaperQuickStatusModel: Equatable {
    let statusText: String
    let statusKind: StudioTheme.StatusKind
    let displayTitle: String
    let canCycle: Bool

    static func make(
        wallpaperCount: Int,
        activeWallpaperTitle: String?
    ) -> LiveWallpaperQuickStatusModel {
        guard wallpaperCount > 0 else {
            return LiveWallpaperQuickStatusModel(
                statusText: "NO WALLPAPER",
                statusKind: .warn,
                displayTitle: "No standby wallpaper",
                canCycle: false
            )
        }

        return LiveWallpaperQuickStatusModel(
            statusText: "\(wallpaperCount)",
            statusKind: .ready,
            displayTitle: activeWallpaperTitle ?? "No wallpaper selected",
            canCycle: wallpaperCount >= 2
        )
    }
}
