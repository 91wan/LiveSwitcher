import SwiftUI

extension ProgramMonitorView {
    var monitorUtilitiesStack: some View {
        VStack(spacing: 10) {
            if !isLiveMode {
                wallpaperTrayCard
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous)
                .fill(StudioTheme.Surface.base.opacity(StudioTheme.Surface.Opacity.overlay))
        )
        .overlay(
            RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous)
                .stroke(StudioTheme.borderSubtle, lineWidth: 1)
        )
    }

    var wallpaperTrayCard: some View {
        let wallpaperCount = viewModel.backgroundWallpapers.count

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("待机壁纸")
                        .font(StudioTheme.sectionTitle())
                        .foregroundStyle(StudioTheme.textPrimary)
                }
                Spacer()
                if CountPillVisibilityPolicy.shouldShow(count: wallpaperCount) {
                    CountPill("\(wallpaperCount) 张", kind: .ready)
                }
            }

            if viewModel.backgroundWallpapers.isEmpty {
                InlineWarningBanner(title: "没有待机壁纸", message: "导入一张中性图片作为备用画面。", kind: .warn)
                Button {
                    WallpaperImportService.presentPicker(viewModel: viewModel)
                } label: {
                    Label("导入壁纸...", systemImage: "photo.badge.plus")
                        .font(StudioTheme.TypeScale.caption.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 32)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else {
                WallpaperGalleryRow()
                    .frame(maxHeight: 92)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous)
                .fill(StudioTheme.Surface.base)
        )
        .overlay(
            RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous)
                .stroke(StudioTheme.borderSubtle, lineWidth: 1)
        )
    }
}
