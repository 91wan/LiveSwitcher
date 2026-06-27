import SwiftUI

struct BGMPlaylistHeader: View {
    let itemCount: Int
    let controls: BGMControlsState

    var body: some View {
        ZStack {
            VStack(spacing: 2) {
                Text("音乐播放机")
                    .font(StudioTheme.title())
                    .foregroundStyle(StudioTheme.textPrimary)
                Text("\(itemCount) 首已入库")
                    .font(StudioTheme.caption())
                    .foregroundStyle(StudioTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)

            HStack {
                Spacer()
                if StatusBadgeVisibilityPolicy.shouldShow(
                    text: controls.displayStatusText,
                    kind: controls.displayStatusKind
                ) {
                    StatusBadge(controls.displayStatusText, kind: controls.displayStatusKind)
                }
            }
        }
    }
}
