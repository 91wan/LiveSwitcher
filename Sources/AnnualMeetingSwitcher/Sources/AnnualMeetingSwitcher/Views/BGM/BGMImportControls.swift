import SwiftUI

struct BGMImportControls: View {
    let onOpenMusicPicker: () -> Void

    var body: some View {
        Button {
            onOpenMusicPicker()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(StudioTheme.TypeScale.heading.weight(.bold))
                    .accessibilityHidden(true)
                Text("添加音乐文件")
                    .font(StudioTheme.TypeScale.heading.weight(.bold))
                Spacer()
                Image(systemName: "arrow.up.doc.fill")
                    .font(StudioTheme.TypeScale.body.weight(.semibold))
                    .accessibilityHidden(true)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
        }
        .background(
            RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                .fill(StudioTheme.Action.primary)
        )
        .buttonStyle(.plain)
        .accessibilityLabel("添加音乐文件")
    }
}
