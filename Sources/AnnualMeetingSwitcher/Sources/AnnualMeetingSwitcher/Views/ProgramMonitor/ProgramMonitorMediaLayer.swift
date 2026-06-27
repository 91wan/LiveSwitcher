import SwiftUI

extension ProgramMonitorView {
    @ViewBuilder
    var mediaLayer: some View {
        if VideoLayerVisibilityModel.shouldShowMonitorVideoLayer(
            sourceKind: viewModel.currentProgramItem?.sourceKind,
            hasLoadedMedia: avCoordinator.hasLoadedMedia
        ) {
            VideoPlayerView(coordinator: avCoordinator)
                .transition(.opacity)
                .overlay(alignment: .bottomTrailing) {
                    if !avCoordinator.isPlaying {
                        Text("暂停")
                            .font(StudioTheme.TypeScale.caption.weight(.black))
                            .foregroundStyle(StudioTheme.monitorText)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(StudioTheme.monitorOverlayFill, in: Capsule(style: .continuous))
                            .padding(12)
                    }
                }
        } else if let item = viewModel.currentProgramItem {
            VStack(spacing: 8) {
                Text(item.title)
                    .font(StudioTheme.TypeScale.display.weight(.bold))
                    .foregroundStyle(StudioTheme.monitorText)
                if !item.subtitle.isEmpty {
                    Text(item.subtitle)
                        .font(StudioTheme.TypeScale.heading.weight(.regular))
                        .foregroundStyle(StudioTheme.monitorText.opacity(0.6))
                }
            }
            .transition(.opacity)
        } else {
            VStack(spacing: 8) {
                Text("待机中")
                    .font(StudioTheme.TypeScale.display.weight(.bold))
                    .foregroundStyle(StudioTheme.monitorText)
                Text("未载入信号")
                    .font(StudioTheme.TypeScale.body.weight(.black))
                    .foregroundStyle(StudioTheme.monitorText.opacity(0.7))
            }
            .transition(.opacity)
        }
    }
}
