import SwiftUI

enum SetupSideRailLayoutMetrics {
    static let width = StudioTheme.directorRailWidth
    static let cornerRadius: CGFloat = 28
    static let padding: CGFloat = 16
    static let contentSpacing: CGFloat = 10
    static let footerHorizontalPadding: CGFloat = 4
    static let verifiedMinimumWindowSize = CGSize(width: 1360, height: 700)
}

struct SetupSideRailChrome<Content: View, Footer: View>: View {
    var scrollsContent = false
    @ViewBuilder var footer: Footer
    @ViewBuilder var content: Content

    init(
        scrollsContent: Bool = false,
        @ViewBuilder footer: () -> Footer,
        @ViewBuilder content: () -> Content
    ) {
        self.scrollsContent = scrollsContent
        self.footer = footer()
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SetupSideRailLayoutMetrics.contentSpacing) {
            railContent
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            footer
        }
        .padding(SetupSideRailLayoutMetrics.padding)
        .frame(width: SetupSideRailLayoutMetrics.width)
        .frame(maxHeight: .infinity)
        .studioCard(cornerRadius: SetupSideRailLayoutMetrics.cornerRadius)
    }

    @ViewBuilder
    private var railContent: some View {
        if scrollsContent {
            ScrollView {
                content
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .scrollIndicators(.visible)
        } else {
            content
        }
    }
}

struct SetupSideRailFooter: View {
    let text: String
    let accessibilityLabel: String
    var truncationMode: Text.TruncationMode = .tail

    var body: some View {
        Text(text)
            .font(StudioTheme.caption())
            .foregroundStyle(StudioTheme.textTertiary)
            .lineLimit(1)
            .truncationMode(truncationMode)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, SetupSideRailLayoutMetrics.footerHorizontalPadding)
            .accessibilityLabel(accessibilityLabel)
    }
}
