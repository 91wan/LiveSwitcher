import SwiftUI

@MainActor
struct OverlayLivePreviewColumn: View {
    @Environment(SwitcherViewModel.self) private var viewModel
    let activeOverlayCount: Int
    let hasActiveOverlay: Bool

    private var composerState: OverlayComposerState {
        viewModel.overlayComposerState
    }

    var body: some View {
        let previewModel = livePreviewModel
        let isEmptyPreview = previewModel.layers.isEmpty

        return StudioSectionCard(
            title: "实时预览",
            subtitle: "16:9 预览和当前上屏叠层",
            status: (hasActiveOverlay ? "\(activeOverlayCount) 上屏" : "关闭", hasActiveOverlay ? .live : .idle)
        ) {
            VStack(alignment: .leading, spacing: 12) {
                OverlayLivePreviewCanvas(model: previewModel)
                    .frame(maxWidth: isEmptyPreview ? 320 : .infinity)
                    .frame(height: isEmptyPreview ? 180 : nil)
                    .frame(maxWidth: .infinity, alignment: .center)
                OverlayActiveStatusCard(hasActiveOverlay: hasActiveOverlay)
            }
        }
    }

    private var livePreviewModel: OverlayLivePreviewModel {
        OverlayLivePreviewModel.make(
            isLowerThirdVisible: viewModel.isLowerThirdVisible,
            lowerThirdName: viewModel.lowerThirdName,
            lowerThirdRole: viewModel.lowerThirdRole,
            lowerThirdOrganization: viewModel.lowerThirdOrganization,
            isCountdownActive: viewModel.isCountdownActive,
            countdownSeconds: viewModel.countdownSeconds,
            countdownTitle: viewModel.countdownTitle,
            isTickerActive: viewModel.isTickerActive,
            tickerText: viewModel.tickerText,
            composerState: composerState
        )
    }
}
