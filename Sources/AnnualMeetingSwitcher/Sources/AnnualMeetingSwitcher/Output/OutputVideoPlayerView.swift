import AVFoundation
import AVKit
import Combine
import SwiftUI

// MARK: - AVPlayer 副屏专用封装

/// V34 副屏输出（等比填满版）：
/// - videoGravity = .resizeAspectFill
/// - 根据媒体加载状态、当前节目类型、播放状态控制 AVPlayerView 显隐
/// - 暂停时保持播放器层挂载，仅隐藏副屏播放器层以露出壁纸
struct OutputVideoPlayerView: NSViewRepresentable {
    let coordinator: AVPlayerCoordinator
    let sourceKind: ProgramSourceKind?
    let isPanicModeProvider: @MainActor () -> Bool

    func makeCoordinator() -> VisibilityCoordinator {
        VisibilityCoordinator()
    }

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = coordinator.player
        view.controlsStyle = .none
        view.videoGravity = .resizeAspectFill
        view.autoresizingMask = [.width, .height]
        context.coordinator.bind(
            avCoordinator: coordinator,
            sourceKind: sourceKind,
            isPanicModeProvider: isPanicModeProvider,
            to: view
        )
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        nsView.player = coordinator.player
        nsView.videoGravity = .resizeAspectFill
        context.coordinator.update(
            sourceKind: sourceKind,
            isPanicMode: isPanicModeProvider(),
            hasLoadedMedia: coordinator.hasLoadedMedia,
            isPlaying: coordinator.isPlaying,
            view: nsView
        )
    }

    @MainActor
    class VisibilityCoordinator {
        private var cancellable: AnyCancellable?
        private var sourceKind: ProgramSourceKind?
        private var isPanicModeProvider: @MainActor () -> Bool = { false }

        func bind(
            avCoordinator: AVPlayerCoordinator,
            sourceKind: ProgramSourceKind?,
            isPanicModeProvider: @escaping @MainActor () -> Bool,
            to view: AVPlayerView
        ) {
            self.sourceKind = sourceKind
            self.isPanicModeProvider = isPanicModeProvider
            cancellable = Publishers.CombineLatest(avCoordinator.$hasLoadedMedia, avCoordinator.$isPlaying)
                .receive(on: DispatchQueue.main)
                .sink { [weak self, weak view] hasLoadedMedia, isPlaying in
                    guard let self, let view else { return }
                    self.update(
                        sourceKind: self.sourceKind,
                        isPanicMode: self.isPanicModeProvider(),
                        hasLoadedMedia: hasLoadedMedia,
                        isPlaying: isPlaying,
                        view: view
                    )
                }
        }

        func update(
            sourceKind: ProgramSourceKind?,
            isPanicMode: Bool,
            hasLoadedMedia: Bool,
            isPlaying: Bool,
            view: AVPlayerView
        ) {
            self.sourceKind = sourceKind
            view.isHidden = !VideoLayerVisibilityModel.shouldShowOutputVideoLayer(
                sourceKind: sourceKind,
                hasLoadedMedia: hasLoadedMedia,
                isPlaying: isPlaying,
                isPanicMode: isPanicMode
            )
        }
    }
}
