import Foundation

struct AutoNextVideoControlModel: Equatable {
    let systemImage: String
    let statusKind: StudioTheme.StatusKind

    static func make(isEnabled: Bool, hasCurrentProgram: Bool) -> AutoNextVideoControlModel {
        if isEnabled && hasCurrentProgram {
            return AutoNextVideoControlModel(
                systemImage: "exclamationmark.triangle.fill",
                statusKind: .warn
            )
        }

        return AutoNextVideoControlModel(
            systemImage: "play.rectangle.on.rectangle",
            statusKind: .idle
        )
    }
}
