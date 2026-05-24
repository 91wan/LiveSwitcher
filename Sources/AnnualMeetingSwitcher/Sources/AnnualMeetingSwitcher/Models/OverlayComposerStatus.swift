enum OverlayComposerStatus {
    static func text(isLive: Bool, hasDraftInput: Bool, disabledReason: String?) -> String {
        if isLive { return "LIVE" }
        if !hasDraftInput { return "EMPTY" }
        if disabledReason == nil { return "READY" }
        return "DRAFT"
    }
}
