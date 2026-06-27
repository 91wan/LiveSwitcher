import SwiftUI

extension ProgramMonitorView {
    var compactLiveIndicator: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(StudioTheme.Tone.live)
                .frame(width: 8, height: 8)
            Text("直播")
                .font(StudioTheme.TypeScale.caption.weight(.black))
                .foregroundStyle(StudioTheme.monitorText)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(StudioTheme.monitorOverlayFill, in: Capsule(style: .continuous))
        .overlay(Capsule(style: .continuous).stroke(StudioTheme.borderCritical.opacity(0.75), lineWidth: 1))
        .accessibilityLabel("主输出正在直播")
    }

    var monitorTopChrome: some View {
        GeometryReader { proxy in
            let layout = ProgramMonitorChromeLayoutModel.make(width: Double(proxy.size.width))

            HStack(spacing: 10) {
                monitorStatePill

                if layout.showsFullInlineStatus {
                    monitorInlineStatusRow
                } else if layout.showsCompactInlineStatus {
                    monitorCompactStatusPill
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.top, 12)
            .padding(.horizontal, 12)
        }
    }

    var monitorStatePill: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(viewModel.isBroadcasting ? StudioTheme.Tone.live : StudioTheme.Tone.idle)
                .frame(width: 8, height: 8)
            Text(monitorStateLabel)
                .font(StudioTheme.TypeScale.caption.weight(.bold))
                .foregroundStyle(StudioTheme.monitorText)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(StudioTheme.monitorOverlayFill, in: Capsule())
    }

    var monitorInlineStatusRow: some View {
        let current = ProgramMonitorInfoBlockModel.current(
            item: viewModel.currentProgramItem,
            isBroadcasting: viewModel.isBroadcasting,
            isPlaying: avCoordinator.isPlaying,
            isHTMLLoaded: viewModel.currentHTMLURL != nil
        )
        let next = ProgramMonitorInfoBlockModel.next(item: nextProgramItem)

        return HStack(spacing: 10) {
            monitorInlineStatusItem(current)
            Divider()
                .frame(height: 30)
            monitorInlineStatusItem(next)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(StudioTheme.monitorOverlayFill, in: RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous)
                .stroke(viewModel.isBroadcasting ? StudioTheme.borderCritical : StudioTheme.monitorBorder, lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(monitorInlineAccessibilityLabel)
    }

    func monitorInlineStatusItem(_ model: ProgramMonitorInfoBlockModel) -> some View {
        HStack(spacing: 8) {
            Text(model.title.uppercased())
                .font(StudioTheme.statusLabel())
                .foregroundStyle(StudioTheme.monitorText.opacity(0.58))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            Text(model.value)
                .font(StudioTheme.TypeScale.body.weight(.black))
                .foregroundStyle(StudioTheme.monitorText)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 4)
            Text(model.badgeText)
                .font(StudioTheme.TypeScale.label)
                .foregroundStyle(StudioTheme.color(for: model.status))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var monitorCompactStatusPill: some View {
        let current = ProgramMonitorInfoBlockModel.current(
            item: viewModel.currentProgramItem,
            isBroadcasting: viewModel.isBroadcasting,
            isPlaying: avCoordinator.isPlaying,
            isHTMLLoaded: viewModel.currentHTMLURL != nil
        )
        let next = ProgramMonitorInfoBlockModel.next(item: nextProgramItem)

        return HStack(spacing: 7) {
            Text(current.value)
                .foregroundStyle(StudioTheme.monitorText)
            Text("->")
                .foregroundStyle(StudioTheme.monitorText.opacity(0.55))
            Text(next.value)
                .foregroundStyle(StudioTheme.monitorText.opacity(0.82))
        }
        .font(StudioTheme.TypeScale.caption.weight(.bold))
        .lineLimit(1)
        .minimumScaleFactor(0.78)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(StudioTheme.monitorOverlayFill, in: Capsule(style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(monitorInlineAccessibilityLabel)
    }

    var monitorInlineAccessibilityLabel: String {
        let current = ProgramMonitorInfoBlockModel.current(
            item: viewModel.currentProgramItem,
            isBroadcasting: viewModel.isBroadcasting,
            isPlaying: avCoordinator.isPlaying,
            isHTMLLoaded: viewModel.currentHTMLURL != nil
        )
        let next = ProgramMonitorInfoBlockModel.next(item: nextProgramItem)

        return "主输出状态。当前 \(current.accessibilityLabel)。下一项 \(next.accessibilityLabel)。"
    }

    var monitorState: ProgramMonitorStateModel {
        ProgramMonitorStateModel.make(
            isBroadcasting: viewModel.isBroadcasting,
            currentItem: viewModel.currentProgramItem
        )
    }

    var monitorStateLabel: String {
        monitorState.label
    }

    var monitorStateKind: StudioTheme.StatusKind {
        monitorState.kind
    }
}
