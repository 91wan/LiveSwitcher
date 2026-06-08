import Foundation

enum ProgramSourceUnavailableReason: String, Equatable {
    case sourceURLMissing
    case fileMissing
}

struct ProgramSourceAvailabilityResult: Equatable {
    var kind: ProgramSourceKind
    var unavailableReason: ProgramSourceUnavailableReason?
}

enum ProgramSourceAvailabilityPolicy {
    static func availability(
        for item: ProgramItem,
        fileExists: (String) -> Bool
    ) -> ProgramSourceAvailabilityResult {
        let kind = availabilityKind(for: item)

        switch kind {
        case .media, .html, .keynote, .pptx:
            guard let url = item.sourceURL else {
                return ProgramSourceAvailabilityResult(kind: kind, unavailableReason: .sourceURLMissing)
            }
            guard fileExists(url.path) else {
                return ProgramSourceAvailabilityResult(kind: kind, unavailableReason: .fileMissing)
            }
            return ProgramSourceAvailabilityResult(kind: kind, unavailableReason: nil)
        case .activeDeck, .agendaMarker, .unsupported:
            return ProgramSourceAvailabilityResult(kind: kind, unavailableReason: nil)
        }
    }

    static func supportLabel(for kind: ProgramSourceKind) -> String {
        switch kind {
        case .media:
            return "media"
        case .html:
            return "html"
        case .keynote:
            return "keynote"
        case .pptx:
            return "pptx"
        case .activeDeck:
            return "activeDeck"
        case .agendaMarker:
            return "agendaMarker"
        case .unsupported:
            return "unsupported"
        }
    }

    private static func availabilityKind(for item: ProgramItem) -> ProgramSourceKind {
        if item.sourceURL != nil || item.isAgendaMarker || item.sourceKind == .activeDeck {
            return item.sourceKind
        }

        let label = item.subtitle.uppercased()
        if label.contains("VIDEO") || label.contains("AUDIO") || label.contains("MEDIA") {
            return .media
        }
        if label.contains("HTML") {
            return .html
        }
        if label.contains("PPT") {
            return .pptx
        }
        return item.sourceKind
    }
}
