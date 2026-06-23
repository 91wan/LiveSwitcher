import SwiftUI

enum CornerLogoPosition: String, CaseIterable, Equatable {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight

    var displayName: String {
        switch self {
        case .topLeft:
            return "左上"
        case .topRight:
            return "右上"
        case .bottomLeft:
            return "左下"
        case .bottomRight:
            return "右下"
        }
    }

    var shortLabel: String {
        displayName
    }

    var alignment: Alignment {
        switch self {
        case .topLeft:
            return .topLeading
        case .topRight:
            return .topTrailing
        case .bottomLeft:
            return .bottomLeading
        case .bottomRight:
            return .bottomTrailing
        }
    }

    var monitorAlignment: Alignment {
        alignment
    }

    func monitorPadding(chromeVisible: Bool) -> EdgeInsets {
        let base: CGFloat = 16
        let safeTop: CGFloat = 64
        switch self {
        case .topLeft, .topRight:
            return EdgeInsets(top: chromeVisible ? safeTop : base, leading: base, bottom: base, trailing: base)
        case .bottomLeft, .bottomRight:
            return EdgeInsets(top: base, leading: base, bottom: base, trailing: base)
        }
    }
}

enum OutputLayerZIndex {
    static let ticker = 2.0
    static let countdown = 3.0
    static let lowerThird = 5.0
    static let cornerLogo = 6.0
    static let fadeToBlack = 8.0
    static let panic = 10.0
}
