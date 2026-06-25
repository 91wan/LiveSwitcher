import AppKit
import SwiftUI

struct ActiveProgramOverlayLayer: View {
    let displayState: OutputDisplayState
    let cornerLogoImage: NSImage?

    var body: some View {
        GeometryReader { geometry in
            let isCornerLogoRenderable = displayState.shouldRenderCornerLogo(hasDecodedImage: cornerLogoImage != nil)
            let plan = OutputOverlayLayoutPlan.make(
                canvasSize: geometry.size,
                isTickerActive: displayState.isTickerActive,
                isCountdownActive: displayState.isCountdownActive,
                isLowerThirdVisible: displayState.isLowerThirdVisible,
                hasLowerThirdOrganization: !displayState.lowerThirdOrganization
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .isEmpty,
                isLogoReady: isCornerLogoRenderable,
                logoPosition: displayState.cornerLogoPosition
            )
            let lowerThirdMetrics = LowerThirdTypographyMetrics.metrics(
                forCanvasHeight: geometry.size.height,
                canvasWidth: geometry.size.width
            )

            ZStack {
                if let countdownFrame = plan.countdownFrame {
                    CountdownOverlay()
                        .frame(width: countdownFrame.width, height: countdownFrame.height)
                        .position(x: countdownFrame.midX, y: countdownFrame.midY)
                        .transition(.opacity)
                        .zIndex(OutputLayerZIndex.countdown)
                }
                if let tickerFrame = plan.tickerFrame {
                    TickerOverlay()
                        .frame(width: tickerFrame.width, height: tickerFrame.height)
                        .position(x: tickerFrame.midX, y: tickerFrame.midY)
                        .transition(.opacity)
                        .zIndex(OutputLayerZIndex.ticker)
                }

                if let lowerThirdFrame = plan.lowerThirdFrame {
                    LowerThirdView(
                        name: displayState.lowerThirdName,
                        role: displayState.lowerThirdRole,
                        organization: displayState.lowerThirdOrganization,
                        isVisible: displayState.isLowerThirdVisible,
                        metrics: lowerThirdMetrics
                    )
                    .frame(width: lowerThirdFrame.width, height: lowerThirdFrame.height, alignment: .leading)
                    .position(x: lowerThirdFrame.midX, y: lowerThirdFrame.midY)
                    .transition(.opacity)
                    .zIndex(OutputLayerZIndex.lowerThird)
                }

                if isCornerLogoRenderable, let logoFrame = plan.logoFrame {
                    OutputCornerLogoLayer(image: cornerLogoImage)
                        .frame(width: logoFrame.width, height: logoFrame.height)
                        .position(x: logoFrame.midX, y: logoFrame.midY)
                        .zIndex(OutputLayerZIndex.cornerLogo)
                }

                if displayState.isFadeToBlackActive {
                    Color.black
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .zIndex(OutputLayerZIndex.fadeToBlack)
                        .accessibilityLabel("切黑已启用")
                }

                if displayState.isPanicMode {
                    PanicLayer()
                        .transition(.opacity)
                        .zIndex(OutputLayerZIndex.panic)
                }
            }
        }
    }
}

struct OutputCornerLogoLayer: View {
    let image: NSImage?

    var body: some View {
        if let image {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityLabel("角标 Logo 输出")
        }
    }
}
