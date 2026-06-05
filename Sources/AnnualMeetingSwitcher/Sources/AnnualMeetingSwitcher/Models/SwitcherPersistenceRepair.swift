enum SwitcherPersistenceRepair: Equatable {
    case rewriteWallpaperPaths([String])
    case setActiveWallpaperPath(String)
    case removeActiveWallpaper
    case removeCornerLogo
}
