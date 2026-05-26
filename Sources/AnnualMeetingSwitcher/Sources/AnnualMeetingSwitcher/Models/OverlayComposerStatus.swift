enum OverlayComposerStatus {
    static func text(isLive: Bool, hasDraftInput: Bool, disabledReason: String?) -> String {
        if isLive { return "上屏" }
        if !hasDraftInput { return "空" }
        if disabledReason == nil { return "就绪" }
        return "草稿"
    }
}
