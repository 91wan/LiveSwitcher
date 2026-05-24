import SwiftUI

struct ProgramThumbnailView: View {
    let sourceURL: URL?
    let kind: ProgramSourceKind
    let isVideo: Bool
    let displaySize: CGSize

    @State private var thumbnail: NSImage?
    @State private var didFail = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(StudioTheme.monitorSurfaceTop.opacity(0.92))

            if let thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: fallbackSystemImage)
                    .font(StudioTheme.TypeScale.body.weight(.bold))
                    .foregroundStyle(didFail ? StudioTheme.Tone.warn : StudioTheme.textSecondary)
            }
        }
        .frame(width: displaySize.width, height: displaySize.height)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(StudioTheme.monitorBorder, lineWidth: 1)
        )
        .task(id: taskIdentifier) {
            await loadThumbnail()
        }
        .accessibilityHidden(true)
    }

    private var fallbackSystemImage: String {
        ThumbnailService.fallbackSystemImage(for: kind, isVideo: isVideo)
    }

    private var taskIdentifier: String {
        [
            sourceURL?.path ?? "nil",
            kind.displaySourceLabel,
            "\(Int(displaySize.width))x\(Int(displaySize.height))"
        ].joined(separator: "|")
    }

    @MainActor
    private func loadThumbnail() async {
        thumbnail = nil
        didFail = false
        guard let sourceURL else {
            didFail = true
            return
        }

        let targetSize = CGSize(width: displaySize.width * 2, height: displaySize.height * 2)
        if let image = await ThumbnailService.shared.thumbnail(for: sourceURL, kind: kind, targetSize: targetSize) {
            thumbnail = image
        } else {
            didFail = true
        }
    }
}

private extension ProgramSourceKind {
    var displaySourceLabel: String {
        switch self {
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
        case .unsupported:
            return "unsupported"
        }
    }
}
