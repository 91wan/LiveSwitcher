import CoreGraphics
import XCTest
@testable import LiveSwitcher

final class ScreenSelectionPolicyTests: XCTestCase {
    func testPinnedDisplayNameWinsAmongExternalScreens() {
        let screens = [
            candidate(index: 0, name: "Built-in Display", width: 1512, height: 982, scale: 2, isMain: true),
            candidate(index: 1, name: "Confidence Monitor", width: 3840, height: 2160, scale: 1),
            candidate(index: 2, name: "Projector", width: 1920, height: 1080, scale: 1)
        ]

        let selected = DefaultScreenSelectionPolicy.pickExternalCandidate(
            from: screens,
            pinnedDisplayName: "Confidence Monitor"
        )

        XCTAssertEqual(selected?.localizedName, "Confidence Monitor")
    }

    func testClosestPhysicalResolutionTo1080pWinsWithoutPinnedDisplay() {
        let screens = [
            candidate(index: 0, name: "Built-in Display", width: 1512, height: 982, scale: 2, isMain: true),
            candidate(index: 1, name: "4K Monitor", width: 3840, height: 2160, scale: 1),
            candidate(index: 2, name: "Projector 1200p", width: 1920, height: 1200, scale: 1),
            candidate(index: 3, name: "Projector 1080p", width: 1920, height: 1080, scale: 1)
        ]

        let selected = DefaultScreenSelectionPolicy.pickExternalCandidate(
            from: screens,
            pinnedDisplayName: nil
        )

        XCTAssertEqual(selected?.localizedName, "Projector 1080p")
    }

    func testMainOnlySetupReturnsNil() {
        let screens = [
            candidate(index: 0, name: "Built-in Display", width: 1512, height: 982, scale: 2, isMain: true)
        ]

        XCTAssertNil(
            DefaultScreenSelectionPolicy.pickExternalCandidate(
                from: screens,
                pinnedDisplayName: nil
            )
        )
    }

    func testPinnedMainScreenIsIgnoredAndExternalFallbackIsUsed() {
        let screens = [
            candidate(index: 0, name: "Built-in Display", width: 1512, height: 982, scale: 2, isMain: true),
            candidate(index: 1, name: "Projector", width: 1920, height: 1080, scale: 1)
        ]

        let selected = DefaultScreenSelectionPolicy.pickExternalCandidate(
            from: screens,
            pinnedDisplayName: "Built-in Display"
        )

        XCTAssertEqual(selected?.localizedName, "Projector")
    }

    private func candidate(
        index: Int,
        name: String,
        width: CGFloat,
        height: CGFloat,
        scale: CGFloat,
        isMain: Bool = false
    ) -> ScreenSelectionCandidate {
        ScreenSelectionCandidate(
            index: index,
            localizedName: name,
            frame: CGRect(x: 0, y: 0, width: width, height: height),
            backingScaleFactor: scale,
            isMain: isMain
        )
    }
}
