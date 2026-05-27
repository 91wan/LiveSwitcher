import SwiftUI
import AppKit

struct AsyncLocalImage<Placeholder: View, Content: View>: View {
    let url: URL?
    @ViewBuilder var placeholder: () -> Placeholder
    @ViewBuilder var content: (NSImage) -> Content

    @State private var image: NSImage?
    @State private var loadedURL: URL?

    var body: some View {
        Group {
            if let image {
                content(image)
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            await loadImage()
        }
    }

    private func loadImage() async {
        guard let url else {
            image = nil
            loadedURL = nil
            return
        }
        if loadedURL == url { return }
        image = nil
        loadedURL = url

        let data = await Task.detached(priority: .utility) {
            try? Data(contentsOf: url)
        }.value
        guard loadedURL == url else { return }
        image = data.flatMap(NSImage.init(data:))
    }
}
