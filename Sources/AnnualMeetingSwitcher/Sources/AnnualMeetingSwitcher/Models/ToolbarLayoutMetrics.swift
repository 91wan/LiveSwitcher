import CoreGraphics

enum ToolbarLayoutMetrics {
    static let panicMinWidth: CGFloat = 150
    static let panicToModeClusterSpacing: CGFloat = 34
    static let modeButtonMinWidth: CGFloat = 118
    static let modeButtonSpacing: CGFloat = 6
    static let preflightMinWidth: CGFloat = 150
    static let helpMinWidth: CGFloat = 76
    static let interItemSpacing: CGFloat = 10
    static let actionHeight: CGFloat = 46

    static let availableWidthAtMinimumWindow: CGFloat = 510

    static var modeButtonGroupMinWidth: CGFloat {
        modeButtonMinWidth * 2 + modeButtonSpacing
    }

    static var totalMinWidth: CGFloat {
        modeButtonGroupMinWidth + preflightMinWidth + helpMinWidth + interItemSpacing * 2
    }
}
