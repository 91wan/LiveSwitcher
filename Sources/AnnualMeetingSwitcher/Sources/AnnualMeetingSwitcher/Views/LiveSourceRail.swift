import SwiftUI

@MainActor
struct LiveSourceRail: View {
    @Environment(SwitcherViewModel.self) private var viewModel

    var body: some View {
        let programCount = viewModel.programItems.count

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("信号源")
                    .font(StudioTheme.sectionTitle())
                    .foregroundStyle(StudioTheme.textPrimary)
                Spacer()
                if CountPillVisibilityPolicy.shouldShow(count: programCount) {
                    CountPill("\(programCount)", kind: .ready)
                }
            }

            if viewModel.programItems.isEmpty {
                VStack(spacing: 8) {
                    Spacer(minLength: 0)
                    Button {
                        withAnimation(.easeInOut(duration: 0.16)) {
                            viewModel.navigateToSetup(.preview)
                        }
                    } label: {
                        VStack(spacing: 5) {
                            Image(systemName: "gearshape.fill")
                                .font(StudioTheme.TypeScale.title.weight(.black))
                            Text("准备")
                                .font(StudioTheme.TypeScale.caption.weight(.black))
                                .lineLimit(1)
                        }
                            .frame(maxWidth: .infinity)
                            .frame(height: 78)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(StudioTheme.Action.primary)
                    .focusable(false)
                    .accessibilityLabel("切到准备模式")
                    .accessibilityHint("打开节目单添加信号源。")
                    Spacer(minLength: 0)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(viewModel.programItems.enumerated()), id: \.element.id) { index, item in
                            if item.isAgendaMarker {
                                LiveSourceRailMarkerCueRow(
                                    item: item,
                                    queuePosition: index + 1
                                )
                            } else {
                                LiveSourceRailRow(
                                    item: item,
                                    queueRole: role(for: item),
                                    queuePosition: index + 1,
                                    isSelected: item.id == viewModel.currentProgramItem?.id,
                                    isBroadcasting: viewModel.isBroadcasting,
                                    action: { viewModel.switchToProgramAfterReadinessConfirmation(item) }
                                )
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(12)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(StudioTheme.Surface.base.opacity(StudioTheme.Surface.Opacity.overlay), in: RoundedRectangle(cornerRadius: StudioTheme.radiusXL, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: StudioTheme.radiusXL, style: .continuous)
                .stroke(StudioTheme.borderSubtle, lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("现场信号源列表")
    }

    private func role(for item: ProgramItem) -> QueueRole {
        if item.id == viewModel.currentProgramItem?.id {
            return .current
        }
        if item.id == nextProgramItem?.id {
            return .next
        }
        return .queued
    }

    private var nextProgramItem: ProgramItem? {
        ProgramQueueStore.nextPlayableAfterCurrent(
            current: viewModel.currentProgramItem,
            in: viewModel.programItems
        )
    }
}

private struct LiveSourceRailMarkerCueRow: View {
    let item: ProgramItem
    let queuePosition: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 7) {
                ProgramQueueNumberBadge(
                    text: ProgramQueueNumberBadgeMetrics.displayText(for: queuePosition),
                    kind: .marker,
                    foreground: StudioTheme.Tone.warn,
                    background: StudioTheme.Tone.warn.opacity(0.14)
                )

                Image(systemName: "mappin.and.ellipse")
                    .font(StudioTheme.TypeScale.caption.weight(.bold))
                    .foregroundStyle(StudioTheme.Tone.warn)
                    .frame(
                        width: LiveModeLayoutMetrics.transportButtonSize,
                        height: LiveModeLayoutMetrics.transportButtonSize
                    )
                    .background(
                        Circle()
                            .fill(StudioTheme.Tone.warn.opacity(0.12))
                    )

                Text("标记")
                    .font(StudioTheme.TypeScale.label.weight(.semibold))
                    .foregroundStyle(StudioTheme.Tone.warn)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }

            Text(item.title)
                .font(StudioTheme.TypeScale.caption.weight(.semibold))
                .foregroundStyle(StudioTheme.textPrimary)
                .lineLimit(2)
                .truncationMode(.tail)

            if let scheduledStartText {
                Text(scheduledStartText)
                    .font(StudioTheme.TypeScale.label.weight(.semibold))
                    .foregroundStyle(StudioTheme.textSecondary)
                    .lineLimit(1)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(StudioTheme.Tone.warn.opacity(0.07), in: RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                .stroke(StudioTheme.Tone.warn.opacity(0.22), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("议程标记，\(item.title)")
    }

    private var scheduledStartText: String? {
        guard let scheduledStartAt = item.scheduledStartAt else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: scheduledStartAt)
    }
}

private struct LiveSourceRailRow: View {
    let item: ProgramItem
    let queueRole: QueueRole
    let queuePosition: Int
    let isSelected: Bool
    let isBroadcasting: Bool
    let action: () -> Void

    private var labelModel: SourceRailRowLabelModel {
        SourceRailRowLabelModel.make(
            queuePosition: queuePosition,
            queueRole: queueRole,
            sourceLabel: item.displaySourceLabel
        )
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .center, spacing: 7) {
                    ProgramQueueNumberBadge(
                        text: labelModel.numberText,
                        kind: .live,
                        foreground: numberBadgeForeground,
                        background: numberBadgeBackground
                    )

                    ProgramThumbnailView(
                        sourceURL: item.sourceURL,
                        kind: item.sourceKind,
                        isVideo: item.isVideoMedia,
                        displaySize: LiveModeLayoutMetrics.railThumbnailSize
                    )
                    .frame(maxWidth: .infinity)

                    PresentationReadinessDot(result: PresentationReadinessProbe.probe(item: item))
                }

                Text(labelModel.detailText)
                    .font(StudioTheme.TypeScale.label.weight(.semibold))
                    .foregroundStyle(statusColor)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(item.title)
                    .font(StudioTheme.TypeScale.caption.weight(isSelected ? .black : .semibold))
                    .foregroundStyle(StudioTheme.textPrimary)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(rowBackground, in: RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                    .stroke(isSelected ? statusColor.opacity(0.55) : StudioTheme.borderSubtle, lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
            .accessibilityLabel("\(labelModel.accessibilityLabel)，\(item.title)")
    }

    private var statusColor: Color {
        switch queueRole {
        case .current:
            return isBroadcasting ? StudioTheme.Tone.live : StudioTheme.Action.primary
        case .next:
            return StudioTheme.Tone.warn
        case .queued:
            return StudioTheme.Tone.idle
        }
    }

    private var numberBadgeForeground: Color {
        switch queueRole {
        case .current:
            return .white
        case .next:
            return StudioTheme.Tone.warn
        case .queued:
            return StudioTheme.textSecondary
        }
    }

    private var numberBadgeBackground: Color {
        switch queueRole {
        case .current:
            return statusColor
        case .next:
            return StudioTheme.Tone.warn.opacity(0.14)
        case .queued:
            return StudioTheme.Surface.raised
        }
    }

    private var rowBackground: Color {
        isSelected ? statusColor.opacity(0.13) : StudioTheme.Surface.raised.opacity(0.62)
    }
}

