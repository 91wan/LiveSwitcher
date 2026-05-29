import Foundation
import AVFoundation
import Combine

// MARK: - AVPlayer 协调器
// 职责：
// - 管理普通视频文件播放（非 SCK 采集流）
// - 向主界面 Z-Stack 第二层提供视频输入
// - 监听播放进度 & AVPlayerItemDidPlayToEndTime

@MainActor
final class AVPlayerCoordinator: ObservableObject {

    // MARK: - 公开属性

    /// 底层 AVPlayer 实例（供 VideoPlayerView 使用）
    nonisolated let player = AVPlayer()

    /// 当前播放进度 [0.0, 1.0]
    @Published var progress: Double = 0.0

    /// 当前时间（秒）
    @Published var currentTime: Double = 0.0

    /// 总时长（秒），nil 表示未知
    @Published var duration: Double?

    /// 是否正在播放
    @Published var isPlaying: Bool = false

    /// 是否已到达末尾
    @Published var didPlayToEnd: Bool = false

    /// 当前加载的视频 URL
    @Published var currentURL: URL?

    /// Whether a media item is loaded into the player. Pause must keep this true so AppKit keeps the video layer mounted.
    @Published private(set) var hasLoadedMedia: Bool = false

    /// Realtime media-channel power in dBFS when the current AVPlayerItem exposes readable audio.
    @Published var realtimeLevelDB: Float?

    var hasActiveMediaAudioMeterTap: Bool {
        mediaAudioMeterTap != nil
    }

    /// 播放到末尾时的回调（由 ViewModel 绑定）
    var onPlaybackEnded: (() -> Void)?

    // MARK: - 音量（Issue #7/#8: 直接操控 player.volume）

    var volume: Float {
        get { player.volume }
        set { player.volume = newValue }
    }

    // MARK: - Internal state

    nonisolated(unsafe) private var timeObserverToken: Any?
    nonisolated(unsafe) private var durationCancellable: AnyCancellable?
    nonisolated(unsafe) private var endObserver: NSObjectProtocol?
    nonisolated(unsafe) private var mediaAudioMeterTap: MediaAudioMeterTap?

    // MARK: - Init / Deinit

    init() {}

    deinit {
        // Owners must call shutdown() before releasing AVPlayerCoordinator so time observers are removed deterministically.
    }

    // MARK: - 公开 API

    /// 加载并准备视频文件（不自动播放）
    func load(url: URL) {
        cleanupObservers()
        player.pause()
        isPlaying = false
        currentURL = url
        hasLoadedMedia = true
        didPlayToEnd = false
        progress = 0.0
        currentTime = 0.0

        realtimeLevelDB = nil
        let item = AVPlayerItem(url: url)
        installMeterTap(on: item)
        player.replaceCurrentItem(with: item)

        observeItem(item)
        observeEnd(for: item)
    }

    /// 播放
    func play() {
        if player.currentItem == nil {
            guard let currentURL else {
                isPlaying = false
                return
            }
            load(url: currentURL)
        }
        if didPlayToEnd {
            restartFromBeginning()
            return
        }
        player.play()
        isPlaying = true
    }

    /// 暂停
    func pause() {
        player.pause()
        isPlaying = false
    }

    /// 停止并回到开头
    func stop() {
        player.pause()
        cleanupObservers()
        player.replaceCurrentItem(with: nil)  // Bug3/4修复：清空player，监视器和大屏均回到壁纸
        currentURL = nil
        hasLoadedMedia = false
        realtimeLevelDB = nil
        isPlaying = false
        progress = 0.0
        currentTime = 0.0
        duration = nil
        didPlayToEnd = false
    }

    /// Explicit lifecycle cleanup for owners that outlive SwiftUI view churn.
    /// This keeps observer removal deterministic instead of relying on async deinit work.
    func shutdown() {
        stop()
        shutdownNonisolated()
        onPlaybackEnded = nil
    }

    nonisolated func shutdownNonisolated() {
        player.pause()
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
            timeObserverToken = nil
        }
        if let token = endObserver {
            NotificationCenter.default.removeObserver(token)
            endObserver = nil
        }
        durationCancellable = nil
        mediaAudioMeterTap = nil
    }

    /// 跳到开头
    func seekToBeginning() {
        let seekItem = player.currentItem
        didPlayToEnd = false
        player.seek(to: .zero) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self,
                      self.player.currentItem === seekItem
                else { return }
                self.progress = 0.0
                self.currentTime = 0.0
            }
        }
    }

    /// 跳到开头并在 seek 完成后播放，避免从旧时间点抢先出声。
    func restartFromBeginning(onReadyToPlay: (() -> Void)? = nil) {
        if player.currentItem == nil {
            guard let currentURL else {
                isPlaying = false
                return
            }
            load(url: currentURL)
        }
        let wasPlaying = isPlaying
        player.pause()
        if !wasPlaying {
            isPlaying = false
        }
        let seekItem = player.currentItem
        didPlayToEnd = false
        player.seek(to: .zero) { [weak self] finished in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard self.player.currentItem === seekItem else { return }
                self.progress = 0.0
                self.currentTime = 0.0
                guard finished else { return }
                self.play()
                onReadyToPlay?()
            }
        }
    }

    /// 跳到末尾（Skip to end）
    func seekToEnd() {
        guard let dur = duration, dur > 0 else { return }
        let seekItem = player.currentItem
        let target = CMTime(seconds: dur - 0.5, preferredTimescale: 600)
        player.seek(to: target) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self,
                      self.player.currentItem === seekItem
                else { return }
                self.progress = 1.0
                self.currentTime = dur
            }
        }
    }

    /// 跳到指定时间（秒）
    func seek(to seconds: Double) {
        let target = CMTime(seconds: seconds, preferredTimescale: 600)
        player.seek(to: target)
    }

    // MARK: - 观察者管理

    private func observeItem(_ item: AVPlayerItem) {
        // 周期时间观察（每 0.5s 回调一次）
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.applyProgressState(for: time.seconds)
            }
        }

        // 监听 item 的 duration（可能异步就绪）
        durationCancellable = item.publisher(for: \.duration)
            .receive(on: RunLoop.main)
            .sink { [weak self] cmDuration in
                guard let self else { return }
                let secs = cmDuration.seconds
                if secs.isFinite && secs > 0 {
                    self.duration = secs
                    self.applyProgressState(for: self.currentTime)
                }
            }
    }

    private func applyProgressState(for currentTime: Double) {
        let state = PlaybackProgressPolicy.displayState(currentTime: currentTime, duration: duration)
        self.currentTime = state.currentTime
        self.progress = state.progress
    }

    private func observeEnd(for item: AVPlayerItem) {
        if let token = endObserver {
            NotificationCenter.default.removeObserver(token)
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self, weak item] _ in
            Task { @MainActor [weak self, weak item] in
                guard let self,
                      let item,
                      self.player.currentItem === item
                else { return }
                self.isPlaying = false
                self.didPlayToEnd = true
                self.progress = 1.0
                LiveSwitcherTelemetry.playbackReachedEnd()
                self.onPlaybackEnded?()
            }
        }
    }

    private func cleanupObservers() {
        shutdownNonisolated()
    }

    private func installMeterTap(on item: AVPlayerItem) {
        let tap = MediaAudioMeterTap { [weak self] levelDB in
            Task { @MainActor [weak self] in
                self?.realtimeLevelDB = levelDB
            }
        }
        mediaAudioMeterTap = tap
        tap.install(on: item)
    }
}
