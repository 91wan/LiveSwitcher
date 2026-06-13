import Foundation

struct ProgramActivationRuntimeState: Equatable {
    var activeRequestID: UUID?
    var latestCompletedRequestID: UUID?

    var isActive: Bool {
        activeRequestID != nil
    }
}
