import SwiftUI

enum OutputOverlayLayoutMetrics {
    static let tickerAlignment: Alignment = .top
    static let countdownAlignment: Alignment = .center
    static let lowerThirdAlignment: Alignment = .bottomLeading

    static let minimumLayerGap: CGFloat = 16
    static let tickerHorizontalPadding: CGFloat = 0
    static let tickerTopPadding: CGFloat = 0
    static let tickerHeight: CGFloat = 68
    static let tickerCornerRadius: CGFloat = 0
    static let tickerBackgroundOpacity = 0.66

    static let lowerThirdOuterMargin: CGFloat = 60
    static let lowerThirdBottomMargin: CGFloat = 96
    static let lowerThirdHorizontalPadding = lowerThirdOuterMargin
    static let lowerThirdBottomPadding = lowerThirdBottomMargin

    static let logoMaxWidth: CGFloat = 340
    static let logoMaxHeight: CGFloat = 104
    static let logoHorizontalMargin = lowerThirdOuterMargin
    static let logoTopMargin = lowerThirdOuterMargin
    static let logoBottomMargin = lowerThirdBottomMargin
}

struct LowerThirdTypographyMetrics: Equatable {
    let nameFontSize: CGFloat
    let roleFontSize: CGFloat
    let organizationFontSize: CGFloat
    let accentWidth: CGFloat
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat
    let maxWidth: CGFloat
    let minimumTextScaleFactor: CGFloat

    var textSpacing: CGFloat { 4 }
    func cardHeight(hasOrganization: Bool) -> CGFloat {
        let secondLineHeight = hasOrganization ? organizationFontSize + textSpacing : 0
        return nameFontSize + secondLineHeight + verticalPadding * 2
    }

    static func metrics(forCanvasHeight height: CGFloat, canvasWidth width: CGFloat) -> LowerThirdTypographyMetrics {
        let scale = max(height, 1) / 1080
        let nameSize = min(54, max(36, 46 * scale))
        let roleSize = min(34, max(22, nameSize * 0.62))
        let organizationSize = min(30, max(20, 24 * scale))
        return LowerThirdTypographyMetrics(
            nameFontSize: nameSize,
            roleFontSize: roleSize,
            organizationFontSize: organizationSize,
            accentWidth: 6,
            horizontalPadding: 24,
            verticalPadding: 16,
            maxWidth: min(820, width * 0.62),
            minimumTextScaleFactor: 0.72
        )
    }
}

struct OutputOverlayLayoutPlan: Equatable {
    let tickerFrame: CGRect?
    let countdownFrame: CGRect?
    let lowerThirdFrame: CGRect?
    let logoFrame: CGRect?

    static func make(
        canvasSize: CGSize,
        isTickerActive: Bool,
        isCountdownActive: Bool,
        isLowerThirdVisible: Bool,
        hasLowerThirdOrganization: Bool = true,
        isLogoReady: Bool,
        logoPosition: CornerLogoPosition
    ) -> OutputOverlayLayoutPlan {
        let canvas = CGRect(origin: .zero, size: canvasSize)
        let tickerFrame = isTickerActive
            ? CGRect(x: 0, y: 0, width: canvasSize.width, height: OutputOverlayLayoutMetrics.tickerHeight)
            : nil
        let countdownSize = CGSize(
            width: min(760, canvasSize.width * 0.52),
            height: min(320, canvasSize.height * 0.34)
        )
        let countdownFrame = isCountdownActive
            ? CGRect(
                x: (canvasSize.width - countdownSize.width) / 2,
                y: (canvasSize.height - countdownSize.height) / 2,
                width: countdownSize.width,
                height: countdownSize.height
            )
            : nil
        let lowerThirdMetrics = LowerThirdTypographyMetrics.metrics(
            forCanvasHeight: canvasSize.height,
            canvasWidth: canvasSize.width
        )
        let lowerThirdFrame = isLowerThirdVisible
            ? CGRect(
                x: OutputOverlayLayoutMetrics.lowerThirdOuterMargin,
                y: canvasSize.height
                    - OutputOverlayLayoutMetrics.lowerThirdBottomMargin
                    - lowerThirdMetrics.cardHeight(hasOrganization: hasLowerThirdOrganization),
                width: lowerThirdMetrics.maxWidth,
                height: lowerThirdMetrics.cardHeight(hasOrganization: hasLowerThirdOrganization)
            )
            : nil
        let logoFrame = isLogoReady
            ? plannedLogoFrame(
                canvas: canvas,
                tickerFrame: tickerFrame,
                lowerThirdFrame: lowerThirdFrame,
                position: logoPosition
            )
            : nil
        return OutputOverlayLayoutPlan(
            tickerFrame: tickerFrame?.intersection(canvas),
            countdownFrame: countdownFrame?.intersection(canvas),
            lowerThirdFrame: lowerThirdFrame?.intersection(canvas),
            logoFrame: logoFrame?.intersection(canvas)
        )
    }

    private static func plannedLogoFrame(
        canvas: CGRect,
        tickerFrame: CGRect?,
        lowerThirdFrame: CGRect?,
        position: CornerLogoPosition
    ) -> CGRect {
        let horizontalMargin = OutputOverlayLayoutMetrics.logoHorizontalMargin
        let topMargin = OutputOverlayLayoutMetrics.logoTopMargin
        let bottomMargin = OutputOverlayLayoutMetrics.logoBottomMargin
        let verticalMargin = position == .topLeft || position == .topRight ? topMargin : bottomMargin
        let size = CGSize(
            width: min(OutputOverlayLayoutMetrics.logoMaxWidth, max(0, canvas.width - horizontalMargin * 2)),
            height: min(OutputOverlayLayoutMetrics.logoMaxHeight, max(0, canvas.height - verticalMargin * 2))
        )
        var origin: CGPoint
        switch position {
        case .topLeft:
            origin = CGPoint(x: horizontalMargin, y: topMargin)
        case .topRight:
            origin = CGPoint(x: canvas.maxX - horizontalMargin - size.width, y: topMargin)
        case .bottomLeft:
            origin = CGPoint(x: horizontalMargin, y: canvas.maxY - bottomMargin - size.height)
        case .bottomRight:
            origin = CGPoint(x: canvas.maxX - horizontalMargin - size.width, y: canvas.maxY - bottomMargin - size.height)
        }

        if position == .topLeft || position == .topRight,
           let tickerFrame {
            origin.y = max(origin.y, tickerFrame.maxY + OutputOverlayLayoutMetrics.minimumLayerGap)
        }

        if position == .bottomLeft,
           let lowerThirdFrame {
            let preferredY = lowerThirdFrame.minY - OutputOverlayLayoutMetrics.minimumLayerGap - size.height
            origin.y = max(topMargin, preferredY)
            if CGRect(origin: origin, size: size).intersects(lowerThirdFrame) {
                origin.x = min(
                    canvas.maxX - horizontalMargin - size.width,
                    lowerThirdFrame.maxX + OutputOverlayLayoutMetrics.minimumLayerGap
                )
            }
        }

        origin.x = min(max(origin.x, canvas.minX), max(canvas.minX, canvas.maxX - size.width))
        origin.y = min(max(origin.y, canvas.minY), max(canvas.minY, canvas.maxY - size.height))
        return CGRect(origin: origin, size: size)
    }
}
