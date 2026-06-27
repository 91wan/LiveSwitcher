import SwiftUI

struct BGMPanelStatusRow: View {
    let controls: BGMControlsState

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(StudioTheme.color(for: controls.displayStatusKind))
                .frame(width: 8, height: 8)
            Text(statusRowText(for: controls))
                .font(StudioTheme.TypeScale.body.weight(.semibold))
                .foregroundStyle(StudioTheme.textSecondary)
        }
    }

    private func statusRowText(for controls: BGMControlsState) -> String {
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
