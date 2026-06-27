enum BGMPanelStatusCopy {
    static func text(for controls: BGMControlsState) -> String {
        switch controls.displayStatusText {
        case "播放中":
            return "BGM 播放中"
        case "已选":
            return "BGM 已选中"
        case "待选":
            return "请选择 BGM"
        case "空":
            return "请添加 BGM"
        default:
            return controls.displayStatusText
        }
    }
}
