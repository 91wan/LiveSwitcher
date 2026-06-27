import SwiftUI

@MainActor
struct LiveRuntimeStatusBar: View {
    @Environment(SwitcherViewModel.self) private var viewModel

    var body: some View {
        HStack(spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(runtimeStatus.chips.enumerated()), id: \.offset) { _, chip in
                        statusChip(chip)
                    }
                }
                .padding(.vertical, 2)
            }
            Spacer()
            Text("v\(AppConfiguration.appVersion)")
                .font(StudioTheme.caption())
                .foregroundStyle(StudioTheme.textTertiary)
        }
        .padding(.horizontal, 10)
        .frame(maxHeight: .infinity)
        .background(StudioTheme.Surface.base.opacity(0.62), in: Capsule(style: .continuous))
        .overlay(Capsule(style: .continuous).stroke(StudioTheme.borderSubtle, lineWidth: 1))
        .accessibilityLabel("现场运行状态。\(statusText)")
    }

    private func statusChip(_ chip: LiveRuntimeStatusChip) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(StudioTheme.color(for: chip.kind))
                .frame(width: 7, height: 7)
                .accessibilityHidden(true)
            Text(chip.text)
                .font(StudioTheme.caption())
                .foregroundStyle(StudioTheme.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 8)
        .frame(height: 24)
        .background(StudioTheme.Surface.raised.opacity(0.82), in: Capsule(style: .continuous))
        .overlay(Capsule(style: .continuous).stroke(StudioTheme.borderSubtle, lineWidth: 1))
    }

    private var statusText: String {
        runtimeStatus.text
    }

    private var runtimeStatus: LiveRuntimeStatusModel {
        LiveRuntimeStatusModel.make(snapshot: viewModel.livePreflightSnapshot)
    }
}
