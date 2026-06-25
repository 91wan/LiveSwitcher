import Foundation

struct MonitorChromeVisibility: Equatable {
    let inlineChromeOpacity: Double
    let inlineChromeAllowsHitTesting: Bool
    let showsCompactLiveIndicator: Bool
    let compactLiveIndicatorOpacity: Double

    static func make(
        isPlaying: Bool,
        isHovering: Bool,
        isBroadcasting: Bool,
        isTickerActive: Bool = false
    ) -> MonitorChromeVisibility {
        let inlineChromeVisible = (!isPlaying && !isTickerActive) || isHovering
        let showsCompactLiveIndicator = isBroadcasting && !inlineChromeVisible

        return MonitorChromeVisibility(
            inlineChromeOpacity: inlineChromeVisible ? 1 : 0,
            inlineChromeAllowsHitTesting: inlineChromeVisible,
            showsCompactLiveIndicator: showsCompactLiveIndicator,
            compactLiveIndicatorOpacity: showsCompactLiveIndicator ? 1 : 0
        )
    }
}
