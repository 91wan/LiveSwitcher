import SwiftUI

struct BGMProgressRow: View {
    @ObservedObject var progressStore: BGMProgressStore
    let canSeek: Bool
    let onSeek: (Double) -> Void

    var body: some View {
        VStack(spacing: 4) {
            Slider(
                value: Binding(
                    get: { progressStore.progress },
                    set: { onSeek($0) }
                ),
                in: 0...1
            )
            .tint(StudioTheme.Action.primary)
            .frame(height: 20)
            .disabled(!canSeek)
            .accessibilityLabel("BGM 进度")
            .accessibilityValue("\(formatTime(progressStore.currentTime)) / \(progressStore.duration.map { formatTime($0) } ?? "未知时长")")

            HStack {
                Text(formatTime(progressStore.currentTime))
                    .font(StudioTheme.TypeScale.monoCaption)
                    .foregroundStyle(StudioTheme.textSecondary)
                Spacer()
                if let duration = progressStore.duration {
                    Text(formatTime(duration))
                        .font(StudioTheme.TypeScale.monoCaption)
                        .foregroundStyle(StudioTheme.textSecondary)
                } else {
                    Text("--:--")
                        .font(StudioTheme.TypeScale.monoCaption)
                        .foregroundStyle(StudioTheme.textSecondary)
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .background(StudioTheme.Surface.raised)
        .clipShape(.rect(cornerRadius: StudioTheme.radiusS, style: .continuous))
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let seconds = Int(seconds)
        let minutes = seconds / 60
        let remainder = seconds % 60
        return String(format: "%d:%02d", minutes, remainder)
    }
}
