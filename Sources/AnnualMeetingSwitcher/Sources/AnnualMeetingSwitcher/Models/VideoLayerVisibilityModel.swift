import Foundation

struct VideoLayerVisibilityModel: Equatable {
    let shouldShowMonitorVideoLayer: Bool
    let shouldShowOutputVideoLayer: Bool

    static func make(
        sourceKind: ProgramSourceKind?,
        hasLoadedMedia: Bool,
        isPlaying: Bool
    ) -> VideoLayerVisibilityModel {
        VideoLayerVisibilityModel(
            shouldShowMonitorVideoLayer: shouldShowMonitorVideoLayer(
                sourceKind: sourceKind,
                hasLoadedMedia: hasLoadedMedia
            ),
            shouldShowOutputVideoLayer: shouldShowOutputVideoLayer(
                sourceKind: sourceKind,
                hasLoadedMedia: hasLoadedMedia,
                isPlaying: isPlaying
            )
        )
    }

    static func shouldShowMonitorVideoLayer(
        sourceKind: ProgramSourceKind?,
        hasLoadedMedia: Bool
    ) -> Bool {
        sourceKind == .media && hasLoadedMedia
    }

    static func shouldShowOutputVideoLayer(
        sourceKind: ProgramSourceKind?,
        hasLoadedMedia: Bool,
        isPlaying: Bool
    ) -> Bool {
        sourceKind == .media && hasLoadedMedia && isPlaying
    }
}
