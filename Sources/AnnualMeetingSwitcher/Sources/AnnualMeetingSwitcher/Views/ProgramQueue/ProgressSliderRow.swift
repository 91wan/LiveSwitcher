import SwiftUI

@MainActor
struct ProgressSliderRow: View {
    @ObservedObject var avCoordinator: AVPlayerCoordinator
    let mediaGeneration: Int
    let onSeekProgress: (Double, Int) -> Void
    @State private var isDragging = false
    @State private var dragValue: Double = 0.0
    @State private var dragGeneration: Int?

    private var displayProgress: Double {
        isDragging ? dragValue : avCoordinator.progress
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(formatTime(avCoordinator.currentTime))
                .font(StudioTheme.TypeScale.monoCaption.weight(.medium))
                .foregroundStyle(StudioTheme.textSecondary)
                .frame(width: 38, alignment: .leading)

            Slider(
                value: Binding(
                    get: { displayProgress },
                    set: { newValue in
                        if !isDragging {
                            dragGeneration = mediaGeneration
                        }
                        isDragging = true
                        dragValue = newValue
                    }
                ),
                in: 0...1
            ) { editing in
                if editing && dragGeneration == nil {
                    dragGeneration = mediaGeneration
                }
                if !editing && isDragging {
                    onSeekProgress(dragValue, dragGeneration ?? mediaGeneration)
                    isDragging = false
                    dragGeneration = nil
                }
            }
            .tint(StudioTheme.Action.primary)
            .layoutPriority(1)
            .accessibilityLabel("当前节目进度")
            .accessibilityValue("\(formatTime(avCoordinator.currentTime)) / \(avCoordinator.duration.map { formatTime($0) } ?? "未知时长")")

            Text(avCoordinator.duration.map { formatTime($0) } ?? "--:--")
                .font(StudioTheme.TypeScale.monoCaption.weight(.medium))
                .foregroundStyle(StudioTheme.textSecondary)
                .frame(width: 38, alignment: .trailing)
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "00:00" }
        let total = Int(seconds)
        let m = total / 60
        let s = total % 60
        return String(format: "%02d:%02d", m, s)
    }
}
