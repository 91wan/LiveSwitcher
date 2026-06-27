import Foundation

struct ProjectionRuntimeState: Equatable {
    var isBroadcasting = false
    var hasExternalDisplay = false
    var lastDisplayLostAt: Date?
    var safetyNotice: String?
}
