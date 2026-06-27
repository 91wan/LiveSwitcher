import SwiftUI

// MARK: - 叠层控制面板

@MainActor
struct OverlayControlPanel: View {
    @Environment(SwitcherViewModel.self) private var viewModel

    private var activeOverlayCount: Int {
        [
            viewModel.isLowerThirdVisible,
            viewModel.isCountdownActive,
            viewModel.isTickerActive
        ].filter { $0 }.count
    }

    private var hasActiveOverlay: Bool {
        activeOverlayCount > 0
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 18) {
                composerColumn
                    .frame(minWidth: 420, maxWidth: 560)
                OverlayLivePreviewColumn(activeOverlayCount: activeOverlayCount, hasActiveOverlay: hasActiveOverlay)
                    .frame(minWidth: 360, maxWidth: 460)
            }

            VStack(alignment: .leading, spacing: 18) {
                composerColumn
                OverlayLivePreviewColumn(activeOverlayCount: activeOverlayCount, hasActiveOverlay: hasActiveOverlay)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: StudioTheme.radiusXL, style: .continuous)
                .fill(StudioTheme.Surface.base)
        )
        .overlay(
            RoundedRectangle(cornerRadius: StudioTheme.radiusXL, style: .continuous)
                .stroke(StudioTheme.borderSubtle, lineWidth: 1)
        )
        .shadow(color: StudioTheme.shadowSoft, radius: 18, x: 0, y: 10)
        .onAppear {
            syncTickerSpeedFromViewModel()
        }
        .onChange(of: viewModel.tickerSpeed) { _, _ in
            syncTickerSpeedFromViewModel()
        }
    }

    private var composerState: OverlayComposerState {
        viewModel.overlayComposerState
    }

    private var composerColumn: some View {
        VStack(alignment: .leading, spacing: 16) {
            panelHeader
            OverlayComposerPicker(
                selectedKind: composerBinding(\.selectedKind),
                onSelect: { viewModel.overlayComposerState.select($0) }
            )
            activeComposerCard
        }
    }

    private var panelHeader: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous)
                    .fill(StudioTheme.Action.primary.opacity(0.12))
                Image(systemName: "rectangle.3.group.bubble.left.fill")
                    .font(StudioTheme.TypeScale.title.weight(.bold))
                    .foregroundStyle(StudioTheme.Action.primary)
                    .accessibilityHidden(true)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 6) {
                Text("叠层编辑")
                    .font(StudioTheme.TypeScale.title)
                    .foregroundStyle(.primary)
                Text("一次准备一种叠层；右侧预览和上屏列表会显示当前状态。")
                    .font(StudioTheme.TypeScale.body.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if hasActiveOverlay {
                StatusBadge("\(activeOverlayCount) 上屏", kind: .live)
            }
        }
    }

    @ViewBuilder
    private var activeComposerCard: some View {
        switch composerState.selectedKind {
        case .lowerThird:
            LowerThirdComposerCard()
        case .countdown:
            CountdownComposerCard()
        case .ticker:
            TickerComposerCard()
        }
    }

    private func composerBinding<Value>(_ keyPath: WritableKeyPath<OverlayComposerState, Value>) -> Binding<Value> {
        Binding(
            get: { viewModel.overlayComposerState[keyPath: keyPath] },
            set: { viewModel.overlayComposerState[keyPath: keyPath] = $0 }
        )
    }

    private func syncTickerSpeedFromViewModel() {
        let index = OverlaySpeedSelection.nearestIndex(for: viewModel.tickerSpeed)
        viewModel.overlayComposerState.tickerSpeedIndex = index
        let normalizedSpeed = OverlaySpeedSelection.speed(at: index)
        if viewModel.tickerSpeed != normalizedSpeed {
            viewModel.tickerSpeed = normalizedSpeed
        }
    }
}
