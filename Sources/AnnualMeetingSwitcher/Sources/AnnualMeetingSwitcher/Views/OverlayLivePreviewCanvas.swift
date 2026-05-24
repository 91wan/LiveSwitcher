import SwiftUI

struct OverlayLivePreviewCanvas: View {
    let model: OverlayLivePreviewModel

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous)
                .fill(StudioTheme.monitorSurfaceBottom.opacity(0.95))
                .aspectRatio(16.0 / 9.0, contentMode: .fit)

            if model.layers.isEmpty {
                Text(model.emptyMessage)
                    .font(StudioTheme.TypeScale.body.weight(.bold))
                    .foregroundStyle(StudioTheme.monitorText.opacity(0.45))
            } else {
                VStack {
                    tickerLayer
                    Spacer()
                    countdownLayer
                    Spacer()
                    lowerThirdLayer
                }
                .padding(18)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(model.accessibilityLabel)
    }

    @ViewBuilder
    private var tickerLayer: some View {
        if let layer = model.layers.first(where: { $0.kind == .ticker }) {
            HStack(spacing: 8) {
                if layer.isDraft {
                    draftBadge
                }
                Text(layer.primaryText)
                    .font(StudioTheme.TypeScale.caption.weight(.bold))
                    .lineLimit(1)
            }
            .foregroundStyle(StudioTheme.monitorText)
            .opacity(layer.opacity)
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Color.clear.frame(height: 20)
        }
    }

    @ViewBuilder
    private var countdownLayer: some View {
        if let layer = model.layers.first(where: { $0.kind == .countdown }) {
            VStack(spacing: 4) {
                if layer.isDraft {
                    draftBadge
                }
                if let secondary = layer.secondaryText, !secondary.isEmpty {
                    Text(secondary)
                        .font(StudioTheme.TypeScale.caption.weight(.bold))
                        .foregroundStyle(StudioTheme.monitorText.opacity(0.72))
                        .lineLimit(1)
                }
                Text(layer.primaryText)
                    .font(StudioTheme.TypeScale.display.weight(.black))
                    .foregroundStyle(StudioTheme.monitorText)
            }
            .opacity(layer.opacity)
        } else {
            Color.clear.frame(height: 48)
        }
    }

    @ViewBuilder
    private var lowerThirdLayer: some View {
        if let layer = model.layers.first(where: { $0.kind == .lowerThird }) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        if layer.isDraft {
                            draftBadge
                        }
                        Text(layer.primaryText)
                            .font(StudioTheme.TypeScale.body.weight(.black))
                    }
                    if let secondary = layer.secondaryText {
                        Text(secondary)
                            .font(StudioTheme.TypeScale.label.weight(.medium))
                            .opacity(0.78)
                    }
                }
                Spacer()
            }
            .foregroundStyle(StudioTheme.monitorText)
            .padding(10)
            .background(StudioTheme.Tone.live.opacity(layer.isDraft ? 0.36 : 0.72), in: RoundedRectangle(cornerRadius: StudioTheme.radiusS, style: .continuous))
            .opacity(layer.opacity)
        } else {
            Color.clear.frame(height: 52)
        }
    }

    private var draftBadge: some View {
        Text("DRAFT")
            .font(StudioTheme.TypeScale.label.weight(.black))
            .foregroundStyle(StudioTheme.monitorText.opacity(0.9))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(StudioTheme.monitorOverlayFill, in: Capsule(style: .continuous))
    }
}
