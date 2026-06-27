import CoreGraphics

struct TickerTrackGeometry: Equatable {
    static let internalTextPadding: CGFloat = 8
    static let trackGap: CGFloat = 40
    static let hiddenOffset: CGFloat = 10_000

    let containerWidth: CGFloat
    let textWidth: CGFloat

    init(containerWidth: CGFloat, measuredTextWidth: CGFloat) {
        self.containerWidth = max(0, containerWidth)
        self.textWidth = max(1, measuredTextWidth)
    }

    var initialOffsetA: CGFloat {
        containerWidth + Self.internalTextPadding
    }

    var initialOffsetB: CGFloat {
        initialOffsetA + textWidth + Self.trackGap
    }

    var resetThreshold: CGFloat {
        -textWidth
    }

    func nextOffset(after otherOffset: CGFloat) -> CGFloat {
        max(initialOffsetA, otherOffset + textWidth + Self.trackGap)
    }
}
