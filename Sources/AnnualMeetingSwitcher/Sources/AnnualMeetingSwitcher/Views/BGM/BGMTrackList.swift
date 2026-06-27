import SwiftUI

@MainActor
struct BGMTrackList: View {
    let items: [BGMItem]
    var viewModel: SwitcherViewModel
    let selectedCategory: BGMCategory

    var body: some View {
        Group {
            if items.isEmpty {
                EmptyStateView(
                    title: "暂无曲目",
                    message: "添加音乐后，现场 BGM 列表会显示在这里。",
                    systemImage: "music.note.list"
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(StudioTheme.Surface.raised)
                .clipShape(.rect(cornerRadius: StudioTheme.radiusS, style: .continuous))
            } else {
                List {
                    ForEach(items) { bgm in
                        BGMTrackRow(bgm: bgm, viewModel: viewModel)
                            .accessibilityHint("拖拽调整顺序。")
                            .listRowInsets(EdgeInsets(top: 2, leading: 4, bottom: 2, trailing: 4))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                    .onMove { from, to in
                        viewModel.moveBGMItems(in: selectedCategory, from: from, to: to)
                    }
                }
                .listStyle(.plain)
                .frame(height: min(CGFloat(items.count) * 52, 280))
                .background(StudioTheme.Surface.raised)
                .clipShape(.rect(cornerRadius: StudioTheme.radiusS, style: .continuous))
            }
        }
    }
}
