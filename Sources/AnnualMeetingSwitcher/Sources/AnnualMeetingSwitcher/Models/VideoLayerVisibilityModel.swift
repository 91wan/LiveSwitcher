import Foundation

struct VideoLayerVisibilityModel: Equatable {
    let shouldShowVideoLayer: Bool

    static func make(sourceKind: ProgramSourceKind?, hasLoadedMedia: Bool) -> VideoLayerVisibilityModel {
        VideoLayerVisibilityModel(
            shouldShowVideoLayer: shouldShowVideoLayer(sourceKind: sourceKind, hasLoadedMedia: hasLoadedMedia)
        )
    }

    static func shouldShowVideoLayer(sourceKind: ProgramSourceKind?, hasLoadedMedia: Bool) -> Bool {
        sourceKind == .media && hasLoadedMedia
    }
}
