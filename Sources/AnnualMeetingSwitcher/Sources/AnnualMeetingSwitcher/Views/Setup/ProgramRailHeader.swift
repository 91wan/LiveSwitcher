import SwiftUI

struct ProgramRailHeader: View {
    let programCount: Int
    let onRefreshKeynote: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("节目单")
                    .font(StudioTheme.title())
                    .foregroundStyle(StudioTheme.textPrimary)
                Text("\(programCount) 个节目")
                    .font(StudioTheme.caption())
                    .foregroundStyle(StudioTheme.textSecondary)
            }
            Spacer()
            if CountPillVisibilityPolicy.shouldShow(count: programCount) {
                CountPill("\(programCount)", kind: .ready)
            }
            Button(action: onRefreshKeynote) {
                Image(systemName: "arrow.clockwise")
                    .font(StudioTheme.TypeScale.body.weight(.bold))
                    .foregroundStyle(StudioTheme.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: StudioTheme.radiusS, style: .continuous)
                            .fill(StudioTheme.Surface.raised)
                    )
            }
            .buttonStyle(.plain)
            .focusable(false)
            .help("刷新 / 重新扫描 Keynote")
            .accessibilityLabel("刷新 Keynote 信号源")
        }
    }
}
