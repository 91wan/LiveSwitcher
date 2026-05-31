enum MainWindowFallbackPolicy {
    static func shouldReuseMainWindow(
        isVisible: Bool,
        isMiniaturized: Bool,
        isOcclusionVisible: Bool
    ) -> Bool {
        // Occlusion can be stale during launch/reopen ordering. A visible,
        // non-minimized main window is valid even when another window covers it.
        isVisible && !isMiniaturized
    }
}
