import SwiftUI

extension StudioTheme {
    enum StatusKind: String, Equatable {
        case ready
        case live
        case warn
        case fail
        case muted
        case idle

        var accessibilityName: String {
            switch self {
            case .ready: return "Ready"
            case .live: return "On Air"
            case .warn: return "Warning"
            case .fail: return "Fail"
            case .muted: return "Muted"
            case .idle: return "Idle"
            }
        }
    }

    static func color(for kind: StatusKind) -> Color {
        switch kind {
        case .ready: return Tone.ready
        case .live: return Tone.live
        case .warn: return Tone.warn
        case .fail: return Tone.fail
        case .muted: return Tone.muted
        case .idle: return Tone.idle
        }
    }
}

struct StatusBadge: View {
    let text: String
    let kind: StudioTheme.StatusKind
    let systemImage: String?

    init(_ text: String, kind: StudioTheme.StatusKind, systemImage: String? = nil) {
        self.text = text
        self.kind = kind
        self.systemImage = systemImage
    }

    var body: some View {
        HStack(spacing: 5) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(StudioTheme.TypeScale.caption.weight(.black))
            }
            Text(text)
                .font(StudioTheme.statusLabel())
                .lineLimit(1)
        }
        .foregroundStyle(StudioTheme.color(for: kind))
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            Capsule(style: .continuous)
                .fill(StudioTheme.color(for: kind).opacity(0.12))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(StudioTheme.color(for: kind).opacity(0.22), lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(kind.accessibilityName): \(text)")
    }
}

struct CountPill: View {
    let text: String
    let kind: StudioTheme.StatusKind

    init(_ text: String, kind: StudioTheme.StatusKind = .idle) {
        self.text = text
        self.kind = kind
    }

    var body: some View {
        Text(text)
            .font(StudioTheme.statusLabel())
            .foregroundStyle(StudioTheme.color(for: kind))
            .padding(.horizontal, 9)
            .frame(height: StudioTheme.controlHeightS)
            .background(StudioTheme.color(for: kind).opacity(0.11), in: Capsule(style: .continuous))
            .accessibilityLabel(text)
    }
}

struct MetricRow: View {
    let title: String
    let value: String
    let subtitle: String?
    let kind: StudioTheme.StatusKind

    init(title: String, value: String, subtitle: String? = nil, kind: StudioTheme.StatusKind = .idle) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.kind = kind
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: StudioTheme.spacingM) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(StudioTheme.caption())
                    .foregroundStyle(StudioTheme.textSecondary)
                if let subtitle {
                    Text(subtitle)
                        .font(StudioTheme.TypeScale.label.weight(.medium))
                        .foregroundStyle(StudioTheme.textTertiary)
                }
            }
            Spacer(minLength: 0)
            Text(value)
                .font(StudioTheme.TypeScale.numeric)
                .foregroundStyle(StudioTheme.color(for: kind))
        }
        .accessibilityElement(children: .combine)
    }
}

struct InlineWarningBanner: View {
    let title: String
    let message: String
    let kind: StudioTheme.StatusKind

    init(title: String, message: String, kind: StudioTheme.StatusKind = .warn) {
        self.title = title
        self.message = message
        self.kind = kind
    }

    var iconName: String {
        switch kind {
        case .fail:
            return "xmark.octagon.fill"
        case .warn:
            return "exclamationmark.triangle.fill"
        case .ready:
            return "checkmark.seal.fill"
        case .live:
            return "dot.radiowaves.left.and.right"
        case .idle, .muted:
            return "info.circle.fill"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: StudioTheme.spacingS) {
            Image(systemName: iconName)
                .foregroundStyle(StudioTheme.color(for: kind))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(StudioTheme.TypeScale.caption.weight(.black))
                    .foregroundStyle(StudioTheme.textPrimary)
                Text(message)
                    .font(StudioTheme.caption())
                    .foregroundStyle(StudioTheme.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(StudioTheme.spacingM)
        .background(StudioTheme.color(for: kind).opacity(0.09), in: RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                .stroke(StudioTheme.color(for: kind).opacity(0.20), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}
