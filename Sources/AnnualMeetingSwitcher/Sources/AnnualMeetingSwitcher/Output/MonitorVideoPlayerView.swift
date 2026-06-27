import AVKit
import SwiftUI

// MARK: - ContentView 中使用的监视器 VideoPlayerView（保持不变）

struct VideoPlayerView: NSViewRepresentable {
    let coordinator: AVPlayerCoordinator

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = coordinator.player
        view.controlsStyle = .none
        view.videoGravity = .resizeAspect
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        nsView.player = coordinator.player
    }
}
