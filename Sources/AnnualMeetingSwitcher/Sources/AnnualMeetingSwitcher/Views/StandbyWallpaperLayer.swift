import SwiftUI

@MainActor
struct StandbyWallpaperLayer: View {
    let image: NSImage?

    var body: some View {
        if let wallpaper = image {
            Image(nsImage: wallpaper)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        } else {
            Color.black
        }
    }
}
