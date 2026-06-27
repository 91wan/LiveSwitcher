import Foundation
import XCTest

func repositorySource(_ relativePath: String) throws -> String {
    let root = try repositoryRoot()
    if isLiveModeViewSourcePath(relativePath) {
        return try liveModeSourceTextAggregate(repositoryRoot: root)
    }
    if isProgramMonitorViewSourcePath(relativePath) {
        return try programMonitorSourceTextAggregate(repositoryRoot: root)
    }
    if isRunQueueViewSourcePath(relativePath) {
        return try runQueueSourceTextAggregate(repositoryRoot: root)
    }
    return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
}

func optionalRepositorySource(_ relativePath: String) throws -> String? {
    let root = try repositoryRoot()
    if isLiveModeViewSourcePath(relativePath) {
        return try liveModeSourceTextAggregate(repositoryRoot: root)
    }
    if isProgramMonitorViewSourcePath(relativePath) {
        return try programMonitorSourceTextAggregate(repositoryRoot: root)
    }
    if isRunQueueViewSourcePath(relativePath) {
        return try runQueueSourceTextAggregate(repositoryRoot: root)
    }
    let url = root.appendingPathComponent(relativePath)
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

    func slice(from start: String, to end: String) -> String? {
        guard let startRange = range(of: start) else { return nil }
        guard let endRange = range(of: end, range: startRange.upperBound..<endIndex) else { return nil }
        return String(self[startRange.lowerBound..<endRange.upperBound])
    }

    func balancedBlock(after marker: String) -> String? {
        guard let markerRange = range(of: marker) else { return nil }
        guard let braceRange = range(of: "{", range: markerRange.upperBound..<endIndex) else { return nil }
        return balancedBody(startingAt: braceRange.lowerBound)
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
