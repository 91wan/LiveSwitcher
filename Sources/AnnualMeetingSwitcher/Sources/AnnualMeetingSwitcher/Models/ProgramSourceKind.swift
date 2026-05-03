import Foundation

enum ProgramSourceKind: Equatable {
    case media
    case html
    case keynote
    case pptx
    case activeDeck
    case unsupported

    private static let mediaExtensions: Set<String> = [
        "mp4", "mov", "m4v", "avi", "mp3", "aac", "wav", "m4a"
    ]

    init(fileURL url: URL) {
        let ext = url.pathExtension.lowercased()
        if Self.mediaExtensions.contains(ext) {
            self = .media
        } else if ext == "html" || ext == "htm" {
            self = .html
        } else if ext == "key" || ext == "keynote" {
            self = .keynote
        } else if ext == "pptx" {
            self = .pptx
        } else {
            self = .unsupported
        }
    }

    var isImportableFile: Bool {
        switch self {
        case .media, .html, .keynote, .pptx:
            return true
        case .activeDeck, .unsupported:
            return false
        }
    }

    var supportsSeeking: Bool {
        self == .media
    }
}

extension ProgramItem {
    var sourceKind: ProgramSourceKind {
        if let sourceURL {
            return ProgramSourceKind(fileURL: sourceURL)
        }
        if subtitle.uppercased().contains("KEY") {
            return .activeDeck
        }
        return .unsupported
    }
}
