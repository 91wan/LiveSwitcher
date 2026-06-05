import Foundation
import XCTest

func repositorySource(_ relativePath: String) throws -> String {
    try String(contentsOf: repositoryRoot().appendingPathComponent(relativePath), encoding: .utf8)
}

func optionalRepositorySource(_ relativePath: String) throws -> String? {
    let url = try repositoryRoot().appendingPathComponent(relativePath)
    guard FileManager.default.fileExists(atPath: url.path) else { return nil }
    return try String(contentsOf: url, encoding: .utf8)
}

func repositoryRoot() throws -> URL {
    var directory = URL(fileURLWithPath: #filePath)
    while directory.pathComponents.count > 1 {
        directory.deleteLastPathComponent()
        if FileManager.default.fileExists(atPath: directory.appendingPathComponent("docs").path) {
            return directory
        }
    }
    throw XCTSkip("Could not locate repository root from test source path.")
}

extension String {
    func extractedRuntimeFunctionBody(named name: String) -> String? {
        guard let nameRange = range(of: "func \(name)") else { return nil }
        var search = nameRange.upperBound
        while search < endIndex {
            if self[search] == "{" {
                return balancedBody(startingAt: search)
            }
            search = index(after: search)
        }
        return nil
    }

    private func balancedBody(startingAt openingBrace: String.Index) -> String? {
        var depth = 0
        var index = openingBrace
        while index < endIndex {
            if self[index] == "{" {
                depth += 1
            } else if self[index] == "}" {
                depth -= 1
                if depth == 0 {
                    return String(self[openingBrace...index])
                }
            }
            index = self.index(after: index)
        }
        return nil
    }
}
