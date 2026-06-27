import SwiftUI

struct LiveWallpaperPickerThumb: View {
    let item: LiveWallpaperQuickPickerModel.Item

    var body: some View {
        ZStack(alignment: .topTrailing) {
            AsyncLocalImage(url: item.url) {
                Rectangle()
                    .fill(StudioTheme.Surface.raised)
                    .overlay {
                        Image(systemName: "photo")
                            .font(StudioTheme.TypeScale.caption)
                            .foregroundStyle(StudioTheme.textTertiary)
                            .accessibilityHidden(true)
                    }
            } content: { image in
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
            }
            .frame(width: 44, height: 32)
            .clipShape(.rect(cornerRadius: StudioTheme.radiusS))

            if item.isActive {
                Image(systemName: "checkmark.circle.fill")
                    .font(StudioTheme.TypeScale.caption)
                    .foregroundStyle(StudioTheme.Action.primary)
                    .background(StudioTheme.Surface.base.clipShape(Circle()))
                    .offset(x: -3, y: 3)
                    .accessibilityHidden(true)
            }
        }
        .frame(width: 46, height: 34)
        .overlay(
            RoundedRectangle(cornerRadius: StudioTheme.radiusS, style: .continuous)
                .stroke(item.isActive ? StudioTheme.Action.primary : StudioTheme.borderSubtle, lineWidth: item.isActive ? 2 : 1)
        )
    }
}
