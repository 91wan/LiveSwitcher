import Foundation

struct LiveWallpaperQuickPickerModel: Equatable {
    struct Item: Identifiable, Equatable {
        let url: URL
        let title: String
        let isActive: Bool

        var id: URL { url }
    }

    let statusText: String
    let statusKind: StudioTheme.StatusKind
    let displayTitle: String
    let items: [Item]

    var isEmpty: Bool {
        items.isEmpty
    }

    static func make(
        wallpapers: [URL],
        activeWallpaperURL: URL?
    ) -> LiveWallpaperQuickPickerModel {
        guard !wallpapers.isEmpty else {
            return LiveWallpaperQuickPickerModel(
                statusText: "无壁纸",
                statusKind: .warn,
                displayTitle: "没有待机壁纸",
                items: []
            )
        }

        let validActiveURL = activeWallpaperURL.flatMap { activeURL in
            wallpapers.contains(activeURL) ? activeURL : nil
        }

        let items = wallpapers.map { url in
            Item(
                url: url,
                title: url.lastPathComponent,
                isActive: url == validActiveURL
            )
        }

        return LiveWallpaperQuickPickerModel(
            statusText: "\(wallpapers.count)",
            statusKind: .ready,
            displayTitle: validActiveURL?.lastPathComponent ?? "未选择壁纸",
            items: items
        )
    }
}
