import SwiftUI

enum OutputOverlayPlacement: Equatable {
    case tickerTop
    case countdownCenter
    case lowerThirdBottomLeading
}

enum OutputOverlayLayoutMetrics {
    static let tickerAlignment: Alignment = .top
    static let countdownAlignment: Alignment = .center
    static let lowerThirdAlignment: Alignment = .bottomLeading

    static let tickerHorizontalPadding: CGFloat = 48
    static let tickerTopPadding: CGFloat = 28
    static let tickerHeight: CGFloat = 60
    static let tickerCornerRadius: CGFloat = 12
    static let tickerBackgroundOpacity = 0.66

    static let lowerThirdHorizontalPadding: CGFloat = 60
    static let lowerThirdBottomPadding: CGFloat = 56

    static func placements(
        isTickerActive: Bool,
        isCountdownActive: Bool,
        isLowerThirdVisible: Bool
    ) -> [OutputOverlayPlacement] {
        var placements: [OutputOverlayPlacement] = []
        if isTickerActive {
            placements.append(.tickerTop)
        }
        if isCountdownActive {
            placements.append(.countdownCenter)
        }
        if isLowerThirdVisible {
            placements.append(.lowerThirdBottomLeading)
        }
        return placements
    }
}
