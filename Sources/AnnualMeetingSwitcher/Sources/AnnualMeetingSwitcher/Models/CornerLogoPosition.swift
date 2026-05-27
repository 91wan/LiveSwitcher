import SwiftUI

enum CornerLogoPosition: String, CaseIterable, Equatable {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight

    var displayName: String {
        switch self {
        case .topLeft:
            return "Top Left"
        case .topRight:
            return "Top Right"
        case .bottomLeft:
            return "Bottom Left"
        case .bottomRight:
            return "Bottom Right"
        }
    }

    var shortLabel: String {
        switch self {
        case .topLeft:
            return "TL"
        case .topRight:
            return "TR"
        case .bottomLeft:
            return "BL"
        case .bottomRight:
            return "BR"
        }
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
}

enum OutputLayerZIndex {
    static let lowerThird = 5.0
    static let cornerLogo = 6.0
    static let fadeToBlack = 8.0
    static let panic = 10.0
}
