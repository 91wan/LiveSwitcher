enum MainWindowFallbackPolicy {
    enum Origin: Equatable {
        case windowGroup
        case fallback
        case legacyTitleMatch
    }

    static func origin(identifier: String?, title: String) -> Origin? {
        if identifier == "main-console-fallback" {
            return .fallback
        }
        if identifier?.hasPrefix("main-console") == true {
            return .windowGroup
        }
        if title == "LiveSwitcher" {
            return .legacyTitleMatch
        }
        return nil
    }

    static func shouldReuseMainWindow(
        isVisible: Bool,
        isMiniaturized: Bool,
        isOcclusionVisible: Bool
    ) -> Bool {
        // Occlusion can be stale during launch/reopen ordering. A visible,
        // non-minimized main window is valid even when another window covers it.
        isVisible && !isMiniaturized
    }

    static func shouldCloseUnusableMainWindow(origin: Origin) -> Bool {
        switch origin {
        case .windowGroup, .fallback, .legacyTitleMatch:
            return true
        }
    }
}
