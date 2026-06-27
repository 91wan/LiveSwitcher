import Foundation

struct PresentationQueryRuntimeState: Equatable {
    static let consumedRequestLimit = 20

    var activeRequestID: UUID?
    var latestCompletedRequestID: UUID?
    var latestResult: PresentationQueryResult?
    var latestFailure: PresentationQueryFailure?
    var consumedRequestIDs: [UUID] = []

    func hasConsumed(_ id: UUID) -> Bool {
        consumedRequestIDs.contains(id)
    }

    mutating func markConsumed(_ id: UUID) {
        if !hasConsumed(id) {
            consumedRequestIDs.append(id)
        }
        if latestCompletedRequestID == id {
            latestCompletedRequestID = nil
            latestResult = nil
        }
        if latestFailure?.id == id {
            latestFailure = nil
        }
        if consumedRequestIDs.count > Self.consumedRequestLimit {
            consumedRequestIDs.removeFirst(consumedRequestIDs.count - Self.consumedRequestLimit)
        }
    }
}

struct PresentationQueryFailure: Equatable {
    var id: UUID
    var action: String
    var sanitizedMessage: String
}
