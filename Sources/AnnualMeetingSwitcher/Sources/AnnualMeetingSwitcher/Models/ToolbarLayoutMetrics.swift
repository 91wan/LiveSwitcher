import CoreGraphics

enum ToolbarLayoutMetrics {
    static let panicMinWidth: CGFloat = 104
    static let preflightMinWidth: CGFloat = 112
    static let helpMinWidth: CGFloat = 76
    static let interItemSpacing: CGFloat = 10

    static let availableWidthAtMinimumWindow: CGFloat = 360

    static var totalMinWidth: CGFloat {
        panicMinWidth + preflightMinWidth + helpMinWidth + interItemSpacing * 2
    }
}
