import Foundation

struct OverlayLivePreviewModel: Equatable {
    enum LayerKind: Hashable {
        case ticker
        case countdown
        case lowerThird
    }

    struct Layer: Equatable {
        let kind: LayerKind
        let primaryText: String
        let secondaryText: String?
        let isDraft: Bool
        let opacity: Double
    }

    let layers: [Layer]
    let emptyMessage: String

    var accessibilityLabel: String {
        guard !layers.isEmpty else { return emptyMessage }
        let layerSummary = layers.map { layer in
            let state = layer.isDraft ? "草稿" : "上屏"
            return "\(state) \(layer.kind.accessibilityName): \(layer.primaryText)"
        }
        .joined(separator: ". ")
        return "叠层预览。\(layerSummary)。"
    }

    static func make(
        isLowerThirdVisible: Bool,
        lowerThirdName: String,
        lowerThirdTitle: String,
        isCountdownActive: Bool,
        countdownSeconds: Int,
        countdownTitle: String,
        isTickerActive: Bool,
        tickerText: String,
        composerState: OverlayComposerState
    ) -> OverlayLivePreviewModel {
        var layers: [Layer] = []

        if isTickerActive {
            layers.append(Layer(
                kind: .ticker,
                primaryText: trimmed(tickerText),
                secondaryText: nil,
                isDraft: false,
                opacity: 1
            ))
        }

        if isCountdownActive {
            layers.append(Layer(
                kind: .countdown,
                primaryText: formattedTime(countdownSeconds),
                secondaryText: trimmed(countdownTitle),
                isDraft: false,
                opacity: 1
            ))
        }

        if isLowerThirdVisible {
            layers.append(Layer(
                kind: .lowerThird,
                primaryText: trimmed(lowerThirdName),
                secondaryText: trimmed(lowerThirdTitle).isEmpty ? nil : trimmed(lowerThirdTitle),
                isDraft: false,
                opacity: 1
            ))
        }

        if let draftLayer = draftLayer(from: composerState, excludingLiveKinds: Set(layers.map(\.kind))) {
            layers.append(draftLayer)
        }

        return OverlayLivePreviewModel(layers: layers, emptyMessage: "没有上屏叠层")
    }

    private static func draftLayer(
        from composerState: OverlayComposerState,
        excludingLiveKinds liveKinds: Set<LayerKind>
    ) -> Layer? {
        switch composerState.selectedKind {
        case .lowerThird where !liveKinds.contains(.lowerThird):
            let name = composerState.trimmedLowerThirdName
            guard !name.isEmpty else { return nil }
            let title = trimmed(composerState.lowerThirdTitleDraft)
            return Layer(
                kind: .lowerThird,
                primaryText: name,
                secondaryText: title.isEmpty ? nil : title,
                isDraft: true,
                opacity: 0.35
            )
        case .countdown where !liveKinds.contains(.countdown):
            guard composerState.countdownTotalSeconds > 0 else { return nil }
            let title = trimmed(composerState.countdownTitleDraft)
            return Layer(
                kind: .countdown,
                primaryText: formattedTime(composerState.countdownTotalSeconds),
                secondaryText: title.isEmpty ? nil : title,
                isDraft: true,
                opacity: 0.35
            )
        case .ticker where !liveKinds.contains(.ticker):
            let text = composerState.trimmedTickerText
            guard !text.isEmpty else { return nil }
            return Layer(
                kind: .ticker,
                primaryText: text,
                secondaryText: nil,
                isDraft: true,
                opacity: 0.35
            )
        case .lowerThird, .countdown, .ticker:
            return nil
        }
    }

    private static func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func formattedTime(_ seconds: Int) -> String {
        let total = max(seconds, 0)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

private extension OverlayLivePreviewModel.LayerKind {
    var accessibilityName: String {
        switch self {
        case .ticker:
            return "ticker"
        case .countdown:
            return "countdown"
        case .lowerThird:
            return "lower third"
        }
    }
}
