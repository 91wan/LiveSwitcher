import Foundation

enum ProgramSourceKind: Equatable {
    case media
    case html
    case keynote
    case pptx
    case activeDeck
    case agendaMarker
    case unsupported

    private static let mediaExtensions: Set<String> = [
        "mp4", "mov", "m4v", "avi", "mp3", "aac", "wav", "m4a"
    ]
    private static let videoExtensions: Set<String> = ["mp4", "mov", "m4v", "avi"]
    private static let audioExtensions: Set<String> = ["mp3", "aac", "wav", "m4a"]

    init(fileURL url: URL) {
        let ext = url.pathExtension.lowercased()
        if Self.mediaExtensions.contains(ext) {
            self = .media
        } else if ext == "html" || ext == "htm" {
            self = .html
        } else if ext == "key" || ext == "keynote" {
            self = .keynote
        } else if ext == "ppt" || ext == "pptx" {
            self = .pptx
        } else {
            self = .unsupported
        }
    }

    var isImportableFile: Bool {
        switch self {
        case .media, .html, .keynote, .pptx:
            return true
        case .activeDeck, .agendaMarker, .unsupported:
            return false
        }
    }

    var isActivatableProgram: Bool {
        switch self {
        case .media, .html, .keynote, .pptx, .activeDeck:
            return true
        case .agendaMarker, .unsupported:
            return false
        }
    }

    var supportsSeeking: Bool {
        self == .media
    }

    var supportsPresentationControl: Bool {
        switch self {
        case .keynote, .pptx, .activeDeck:
            return true
        case .media, .html, .agendaMarker, .unsupported:
            return false
        }
    }

    static func isVideoFileURL(_ url: URL) -> Bool {
        videoExtensions.contains(url.pathExtension.lowercased())
    }

    static func isAudioFileURL(_ url: URL) -> Bool {
        audioExtensions.contains(url.pathExtension.lowercased())
    }
}

extension ProgramItem {
    var sourceKind: ProgramSourceKind {
        if let sourceURL {
            return ProgramSourceKind(fileURL: sourceURL)
        }
        if isAgendaMarker {
            return .agendaMarker
        }
        if subtitle.uppercased().contains("KEY") {
            return .activeDeck
        }
        return .unsupported
    }

    var supportsSeeking: Bool {
        sourceKind.supportsSeeking
    }

    var supportsPresentationControl: Bool {
        sourceKind.supportsPresentationControl
    }

    var isVideoMedia: Bool {
        guard sourceKind == .media,
              let sourceURL else { return false }
        return ProgramSourceKind.isVideoFileURL(sourceURL)
    }

    var displaySourceLabel: String {
        switch sourceKind {
        case .media:
            if let sourceURL, ProgramSourceKind.isVideoFileURL(sourceURL) {
                return "VIDEO"
            }
            if let sourceURL, ProgramSourceKind.isAudioFileURL(sourceURL) {
                return "AUDIO"
            }
            return "MEDIA"
        case .html:
            return "HTML"
        case .keynote:
            return "KEY"
        case .pptx:
            return "PPTX"
        case .activeDeck:
            return "DECK"
        case .agendaMarker:
            return "MARKER"
        case .unsupported:
            return subtitle.isEmpty ? "FILE" : subtitle.uppercased()
        }
    }
}
