import AppKit
import CoreGraphics

enum ProjectionDisplayPreferences {
    static let pinnedExternalDisplayNameKey = "projection.pinnedExternalDisplayName"
}

struct ScreenSelectionCandidate: Equatable {
    var index: Int
    var localizedName: String
    var frame: CGRect
    var backingScaleFactor: CGFloat
    var isMain: Bool

    var physicalPixelSize: CGSize {
        CGSize(
            width: frame.width * backingScaleFactor,
            height: frame.height * backingScaleFactor
        )
    }
}

struct DefaultScreenSelectionPolicy {
    private static let targetPhysicalSize = CGSize(width: 1920, height: 1080)

    static func pickExternalCandidate(
        from candidates: [ScreenSelectionCandidate],
        pinnedDisplayName: String?
    ) -> ScreenSelectionCandidate? {
        let externalCandidates = candidates.filter { !$0.isMain }
        guard !externalCandidates.isEmpty else { return nil }

        if let pinnedDisplayName,
           !pinnedDisplayName.isEmpty,
           let pinned = externalCandidates.first(where: { $0.localizedName == pinnedDisplayName }) {
            return pinned
        }

        return externalCandidates.min { lhs, rhs in
            let lhsDistance = resolutionDistance(lhs)
            let rhsDistance = resolutionDistance(rhs)
            if lhsDistance == rhsDistance {
                return lhs.index < rhs.index
            }
            return lhsDistance < rhsDistance
        }
    }

    func pickExternal(
        screens: [NSScreen],
        main: NSScreen?,
        pinnedDisplayName: String?
    ) -> NSScreen? {
        guard screens.count > 1 else { return nil }
        let mainScreen = main ?? screens.first
        let candidates = screens.enumerated().map { index, screen in
            ScreenSelectionCandidate(
                index: index,
                localizedName: screen.localizedName,
                frame: screen.frame,
                backingScaleFactor: screen.backingScaleFactor,
                isMain: mainScreen.map { screen == $0 } ?? (index == 0)
            )
        }

        guard let selected = Self.pickExternalCandidate(
            from: candidates,
            pinnedDisplayName: pinnedDisplayName
        ),
              screens.indices.contains(selected.index) else {
            return nil
        }
        return screens[selected.index]
    }

    private static func resolutionDistance(_ candidate: ScreenSelectionCandidate) -> CGFloat {
        let size = candidate.physicalPixelSize
        return abs(size.width - targetPhysicalSize.width) + abs(size.height - targetPhysicalSize.height)
    }
}
