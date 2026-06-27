import SwiftUI

struct BGMTransportControls: View {
    let controls: BGMControlsState
    let isPlaying: Bool
    let playMode: BGMPlayMode
    let defaultPlaybackItem: BGMItem?
    let onSeekToBeginning: () -> Void
    let onPrevious: () -> Void
    let onToggleDefault: (BGMItem) -> Void
    let onNext: () -> Void
    let onToggleLoopMode: () -> Void

    private let diskSize: CGFloat = 32

    var body: some View {
        HStack(spacing: 8) {
            Spacer()

            Button(action: onSeekToBeginning) {
                Image(systemName: "backward.end.alt.fill")
                    .font(StudioTheme.TypeScale.title)
                    .foregroundStyle(controls.canSeekToBeginning ? StudioTheme.textPrimary : StudioTheme.textTertiary)
                    .frame(width: diskSize, height: diskSize)
                    .background(controlDiskFill)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(!controls.canSeekToBeginning)
            .opacity(controls.canSeekToBeginning ? 1 : 0.42)
            .help("回到开头")
            .accessibilityLabel("BGM 回到开头")
            .accessibilityHint(controls.seekDisabledReason ?? "将当前 BGM 回到 00:00。")

            Button(action: onPrevious) {
                Image(systemName: "backward.end.fill")
                    .font(StudioTheme.TypeScale.title)
                    .foregroundStyle(controls.canSkipPrevious ? StudioTheme.textPrimary : StudioTheme.textTertiary)
                    .frame(width: diskSize, height: diskSize)
                    .background(controlDiskFill)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(!controls.canSkipPrevious)
            .opacity(controls.canSkipPrevious ? 1 : 0.42)
            .help("上一首")
            .accessibilityLabel("上一首 BGM")
            .accessibilityHint(controls.skipDisabledReason ?? "播放当前分类的上一首 BGM。")

            Button(action: {
                if let item = defaultPlaybackItem {
                    onToggleDefault(item)
                }
            }) {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(StudioTheme.TypeScale.display)
                    .foregroundStyle(canPlayDefault ? (isPlaying ? StudioTheme.Tone.live : StudioTheme.Action.primary) : StudioTheme.textTertiary)
            }
            .buttonStyle(.plain)
            .disabled(!(controls.canPlay && defaultPlaybackItem != nil))
            .opacity(canPlayDefault ? 1 : 0.42)
            .help(isPlaying ? "暂停 BGM" : "播放 BGM")
            .accessibilityLabel(isPlaying ? "暂停 BGM" : "播放 BGM")
            .accessibilityHint(controls.playDisabledReason ?? (defaultPlaybackItem == nil ? "当前分类没有可播放 BGM。" : "切换 BGM 播放状态。"))

            Button(action: onNext) {
                Image(systemName: "forward.end.fill")
                    .font(StudioTheme.TypeScale.title)
                    .foregroundStyle(controls.canSkipNext ? StudioTheme.textPrimary : StudioTheme.textTertiary)
                    .frame(width: diskSize, height: diskSize)
                    .background(controlDiskFill)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(!controls.canSkipNext)
            .opacity(controls.canSkipNext ? 1 : 0.42)
            .help("下一首")
            .accessibilityLabel("下一首 BGM")
            .accessibilityHint(controls.skipDisabledReason ?? "播放当前分类的下一首 BGM。")

            Button(action: onToggleLoopMode) {
                Image(systemName: playMode == .loopOne ? "repeat.1" : "repeat")
                    .font(StudioTheme.TypeScale.title)
                    .foregroundStyle(playMode == .sequential ? StudioTheme.textSecondary : StudioTheme.Action.primary)
                    .frame(width: diskSize, height: diskSize)
                    .background(controlDiskFill)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help(playMode.rawValue)
            .accessibilityLabel("BGM 循环模式")
            .accessibilityValue(playMode.rawValue)

            Spacer()
        }
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                .fill(StudioTheme.Surface.raised)
        )
    }

    private var canPlayDefault: Bool {
        controls.canPlay && defaultPlaybackItem != nil
    }

    private var controlDiskFill: some View {
        Circle()
            .fill(StudioTheme.Surface.base)
            .shadow(color: StudioTheme.shadowSoft, radius: 3, x: 0, y: 1)
    }
}
