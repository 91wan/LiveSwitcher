import SwiftUI

extension ProgramMonitorView {
    var previewDeckFrame: some View {
        previewDeck
            .frame(maxWidth: .infinity, alignment: .center)
    }

    var previewDeck: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topTrailing) {
                StandbyWallpaperLayer(image: viewModel.backgroundImage)

                mediaLayer
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

                monitorActiveOverlayLayer(in: proxy.size)

                RoundedRectangle(cornerRadius: StudioTheme.monitorRadius, style: .continuous)
                    .stroke(StudioTheme.monitorBorder, lineWidth: 1)

                if viewModel.isBroadcasting {
                    RoundedRectangle(cornerRadius: StudioTheme.monitorRadius, style: .continuous)
                        .stroke(StudioTheme.borderCritical.opacity(0.95), lineWidth: 3)
                        .padding(1)
                }
            }
            .clipShape(.rect(cornerRadius: StudioTheme.monitorRadius, style: .continuous))
        }
        .overlay(alignment: .top) {
            monitorTopChrome
                .opacity(monitorChromeVisibility.inlineChromeOpacity)
                .allowsHitTesting(monitorChromeVisibility.inlineChromeAllowsHitTesting)
        }
        .overlay(alignment: .center) {
            if blackoutStatusModel.kind != .none {
                blackoutStatusOverlay
                    .opacity(monitorChromeVisibility.inlineChromeOpacity)
                    .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if monitorChromeVisibility.showsCompactLiveIndicator {
                compactLiveIndicator
                    .opacity(monitorChromeVisibility.compactLiveIndicatorOpacity)
                    .padding(12)
                    .transition(.opacity)
            }
        }
        .frame(maxHeight: livePreviewMaxHeight)
        .aspectRatio(ProgramMonitorPreviewDeckLayout.aspectRatio, contentMode: .fit)
        .shadow(color: StudioTheme.shadowStrong, radius: 12, x: 0, y: 8)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.16)) {
                isHoveringPreviewDeck = hovering
            }
        }
        .animation(.easeInOut(duration: 0.16), value: monitorChromeVisibility)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(blackoutStatusModel.monitorAccessibilityLabel ?? (viewModel.isBroadcasting ? "主输出正在直播" : "主输出待机"))
    }

    func monitorActiveOverlayLayer(in monitorSize: CGSize) -> some View {
        let logicalSize = ProgramMonitorOverlayCanvas.logicalSize
        let displayState = monitorOutputDisplayState
        let scale = min(
            safeScale(monitorSize.width, logicalSize.width),
            safeScale(monitorSize.height, logicalSize.height)
        )

        return ActiveProgramOverlayLayer(
            displayState: displayState,
            cornerLogoImage: viewModel.cornerLogoImage
        )
        .frame(width: logicalSize.width, height: logicalSize.height)
        .scaleEffect(scale, anchor: .topLeading)
        .frame(width: monitorSize.width, height: monitorSize.height, alignment: .topLeading)
        .clipped()
        .allowsHitTesting(false)
    }

    func safeScale(_ available: CGFloat, _ logical: CGFloat) -> CGFloat {
        guard available > 0, logical > 0 else { return 0 }
        return available / logical
    }

    var livePreviewMaxHeight: CGFloat {
        isLiveMode ? .infinity : 342
    }

    var monitorOutputDisplayState: OutputDisplayState {
        OutputDisplayState.make(from: viewModel)
    }

    var monitorChromeVisibility: MonitorChromeVisibility {
        MonitorChromeVisibility.make(
            isPlaying: isMediaPlaybackActive,
            isHovering: isHoveringPreviewDeck,
            isBroadcasting: viewModel.isBroadcasting,
            isTickerActive: viewModel.isTickerActive,
            isFadeToBlackActive: monitorOutputDisplayState.isFadeToBlackActive,
            isPanicMode: monitorOutputDisplayState.isPanicMode
        )
    }

    var blackoutStatusModel: ProgramMonitorBlackoutStatusModel {
        ProgramMonitorBlackoutStatusModel.make(
            isFadeToBlackActive: monitorOutputDisplayState.isFadeToBlackActive,
            isPanicMode: monitorOutputDisplayState.isPanicMode
        )
    }

    var isMediaPlaybackActive: Bool {
        viewModel.currentProgramItem?.supportsSeeking == true && avCoordinator.isPlaying
    }

    var nextProgramItem: ProgramItem? {
        ProgramQueueStore.nextPlayableAfterCurrent(
            current: viewModel.currentProgramItem,
            in: viewModel.programItems
        )
    }
}

struct ProgramMonitorPreviewDeckLayout: Equatable {
    static let aspectRatio: CGFloat = 16.0 / 9.0

    let size: CGSize
    let leftGutter: CGFloat
    let rightGutter: CGFloat

    static func make(containerWidth: CGFloat, maxHeight: CGFloat) -> ProgramMonitorPreviewDeckLayout {
        guard containerWidth > 0 else {
            return ProgramMonitorPreviewDeckLayout(size: .zero, leftGutter: 0, rightGutter: 0)
        }

        let heightLimitedWidth = maxHeight.isFinite && maxHeight > 0
            ? maxHeight * aspectRatio
            : containerWidth
        let width = min(containerWidth, heightLimitedWidth)
        let size = CGSize(width: width, height: width / aspectRatio)
        let gutter = max(0, (containerWidth - width) / 2)
        return ProgramMonitorPreviewDeckLayout(size: size, leftGutter: gutter, rightGutter: gutter)
    }
}

enum ProgramMonitorOverlayCanvas {
    static let logicalSize = CGSize(width: 1920, height: 1080)
}
