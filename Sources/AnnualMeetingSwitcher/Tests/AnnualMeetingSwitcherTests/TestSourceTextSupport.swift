import Foundation
import XCTest

func sourceText(_ relativePath: String, filePath: String = #filePath) throws -> String {
    try String(contentsOf: repositoryRoot(filePath: filePath).appendingPathComponent(relativePath), encoding: .utf8)
}

func repositoryRoot(filePath: String = #filePath) throws -> URL {
    var directory = URL(fileURLWithPath: filePath)
    while directory.pathComponents.count > 1 {
        directory.deleteLastPathComponent()
        if FileManager.default.fileExists(atPath: directory.appendingPathComponent("docs").path) {
            return directory
        }
    }
    throw XCTSkip("Could not locate repository root from test source path.")
}
