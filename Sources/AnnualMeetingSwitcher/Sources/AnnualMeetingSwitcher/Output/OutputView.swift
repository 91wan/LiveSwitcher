import SwiftUI

// MARK: - 推流输出内容视图

/// 推流大屏展示的 SwiftUI 视图（内容层）
@MainActor
struct OutputView: View {
    @Environment(SwitcherViewModel.self) var viewModel

    var body: some View {
        let displayState = OutputDisplayState.make(from: viewModel)

        ZStack {
            // 背景：黑底或壁纸
            backgroundLayer

            // 媒体内容层
            mediaContentLayer(displayState: displayState)

            ActiveProgramOverlayLayer(
                displayState: displayState,
                cornerLogoImage: viewModel.cornerLogoImage
            )
        }
        .ignoresSafeArea()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 1.0), value: displayState.isFadeToBlackActive)
        .animation(.easeInOut(duration: 0.25), value: displayState.isCountdownActive)
        .animation(.easeInOut(duration: 0.25), value: displayState.isTickerActive)
        .animation(.easeInOut(duration: 0.25), value: displayState.isLowerThirdVisible)
    }

    // MARK: Private Layers

    @ViewBuilder
    private var backgroundLayer: some View {
        StandbyWallpaperLayer(image: viewModel.backgroundImage)
            .ignoresSafeArea()
    }

    @ViewBuilder
    private func mediaContentLayer(displayState: OutputDisplayState) -> some View {
        // AVPlayer 视频层：始终在视图树中
        // 在 AppKit 层通过 nsView.isHidden 控制 AVPlayerLayer 显隐，
        // 避免 Metal 合成层"穿透" opacity 显示最后一帧。
        OutputVideoPlayerView(
            coordinator: viewModel.avCoordinator,
            sourceKind: viewModel.currentProgramItem?.sourceKind,
            isPanicModeProvider: { viewModel.outputPanicIsActive }
        )

        // HTML 大屏展示层（与视频层互斥）
        if let htmlURL = displayState.currentHTMLURL {
            OutputWebView(url: htmlURL)
                .transition(.opacity)
        }
    }
}
