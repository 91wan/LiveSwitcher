import Foundation

struct ProgramActivationRuntimeState: Equatable {
    var activeRequestID: UUID?
    var latestCompletedRequestID: UUID?

    var isActive: Bool {
        activeRequestID != nil
    }

    mutating func startRequest(id: UUID) {
        activeRequestID = id
        latestCompletedRequestID = nil
    }

    mutating func completeRequest(id: UUID) {
        guard activeRequestID == id else { return }
        activeRequestID = nil
        latestCompletedRequestID = id
    }
}
