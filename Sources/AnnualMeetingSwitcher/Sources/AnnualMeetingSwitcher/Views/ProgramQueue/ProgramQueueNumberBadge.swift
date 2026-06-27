import CoreGraphics
import SwiftUI

enum ProgramQueueNumberBadgeKind {
    case setup
    case live
    case marker
}

struct ProgramQueueNumberBadgeMetrics: Equatable {
    let minWidth: CGFloat
    let height: CGFloat
    let horizontalPadding: CGFloat

    static func displayText(for queuePosition: Int) -> String {
        "\(queuePosition)"
    }

    static func metrics(for text: String, kind: ProgramQueueNumberBadgeKind) -> ProgramQueueNumberBadgeMetrics {
        let base = baseMetrics(for: kind)
        let extraCharacters = max(text.count - 2, 0)
        return ProgramQueueNumberBadgeMetrics(
            minWidth: base.minWidth + CGFloat(extraCharacters) * 10,
            height: base.height,
            horizontalPadding: base.horizontalPadding
        )
    }

    private static func baseMetrics(for kind: ProgramQueueNumberBadgeKind) -> ProgramQueueNumberBadgeMetrics {
        switch kind {
        case .setup:
            return ProgramQueueNumberBadgeMetrics(minWidth: 34, height: 32, horizontalPadding: 8)
        case .live, .marker:
            return ProgramQueueNumberBadgeMetrics(minWidth: 32, height: 32, horizontalPadding: 7)
        }
    }
}

struct ProgramQueueNumberBadge: View {
    let text: String
    let kind: ProgramQueueNumberBadgeKind
    let foreground: Color
    let background: Color

    private var metrics: ProgramQueueNumberBadgeMetrics {
        ProgramQueueNumberBadgeMetrics.metrics(for: text, kind: kind)
    }

    var body: some View {
        Text(text)
            .font(StudioTheme.TypeScale.body.weight(.black))
            .foregroundStyle(foreground)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, metrics.horizontalPadding)
            .frame(minWidth: metrics.minWidth, minHeight: metrics.height)
            .background(
                RoundedRectangle(cornerRadius: StudioTheme.radiusS, style: .continuous)
                    .fill(background)
            )
            .accessibilityLabel(text)
    }
}

struct ProgramQueueRowFramePreferenceKey: PreferenceKey {
    static let defaultValue: [UUID: CGRect] = [:]

    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

struct ProgramQueueListFramePreferenceKey: PreferenceKey {
    static let defaultValue: CGRect = .null

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

extension SignalSourceRow {
    var queueBadge: some View {
        ProgramQueueNumberBadge(
            text: queueBadgeText,
            kind: .setup,
            foreground: queueBadgeForeground,
            background: queueBadgeBackground
        )
    }

    var queueBadgeText: String {
        rowModel.queueBadgeText
    }

    var queueBadgeForeground: Color {
        switch queueRole {
        case .current:
            return .white
        case .next:
            return StudioTheme.Tone.warn
        case .queued:
            return StudioTheme.textSecondary
        }
    }

    var queueBadgeBackground: Color {
        switch queueRole {
        case .current:
            return isBroadcasting ? StudioTheme.Tone.live : StudioTheme.Action.primary
        case .next:
            return StudioTheme.Tone.warn.opacity(0.14)
        case .queued:
            return StudioTheme.Surface.raised
        }
    }
}
