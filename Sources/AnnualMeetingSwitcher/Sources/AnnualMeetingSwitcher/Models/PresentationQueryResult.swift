import Foundation

struct PresentationQueryResult: Equatable {
    var openFilePaths: [String]
    var windowNames: [String]

    static let empty = PresentationQueryResult(openFilePaths: [], windowNames: [])
}
