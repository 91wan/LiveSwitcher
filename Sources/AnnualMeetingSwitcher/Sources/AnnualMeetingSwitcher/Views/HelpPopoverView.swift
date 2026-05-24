import SwiftUI

// MARK: - Help

struct HelpPopoverView: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text("LiveSwitcher")
                    .font(StudioTheme.TypeScale.heading.weight(.black))

                Spacer()

                StatusBadge("Help", kind: .idle)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 16)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(HelpCopyModel.sections) { section in
                        HelpSectionView(title: section.title, items: section.items)
                    }

                    Text("Version 0.4.0 | core state split")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 10)
                }
                .padding(24)
            }
        }
        .frame(width: 520, height: 560)
    }
}

private struct HelpSectionView: View {
    let title: String
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            ForEach(items, id: \.self) { item in
                HStack(alignment: .top) {
                    Text("•")
                        .font(StudioTheme.TypeScale.body.weight(.bold))
                        .foregroundStyle(StudioTheme.textSecondary)
                    Text(item)
                        .font(StudioTheme.TypeScale.body)
                        .foregroundStyle(StudioTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

#Preview {
    HelpPopoverView()
        .environmentObject(SwitcherViewModel())
}
