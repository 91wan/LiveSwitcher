import SwiftUI
import UniformTypeIdentifiers

private enum CornerLogoImportService {
    @MainActor
    static func presentPicker(viewModel: SwitcherViewModel) {
        let panel = NSOpenPanel()
        panel.title = "导入角标 Logo"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.image, .png, .jpeg, .gif]
        guard panel.runModal() == .OK,
              let url = panel.url else { return }
        _ = viewModel.setCornerLogo(url: url)
    }
}

@MainActor
struct CornerLogoCard: View {
    @Environment(SwitcherViewModel.self) var viewModel

    var body: some View {
        @Bindable var viewModel = viewModel

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("角标")
                        .font(StudioTheme.sectionTitle())
                        .foregroundStyle(StudioTheme.textPrimary)
                    Text("输出画面的常驻品牌标识")
                        .font(StudioTheme.caption())
                        .foregroundStyle(StudioTheme.textTertiary)
                }
                Spacer()
                switch viewModel.cornerLogoLoadPhase {
                case .off:
                    StatusBadge("关闭", kind: .idle)
                case .loading:
                    StatusBadge("加载中", kind: .warn)
                case .ready:
                    StatusBadge(viewModel.cornerLogoPosition.shortLabel, kind: .ready)
                case .failed:
                    StatusBadge("加载失败", kind: .fail)
                }
            }

            HStack(spacing: 10) {
                logoPreview
                VStack(alignment: .leading, spacing: 8) {
                    Picker("位置", selection: $viewModel.cornerLogoPosition) {
                        ForEach(CornerLogoPosition.allCases, id: \.self) { position in
                            Text(position.displayName)
                                .tag(position)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .help("选择 Logo 显示角落")

                    HStack(spacing: 8) {
                        Button {
                            CornerLogoImportService.presentPicker(viewModel: viewModel)
                        } label: {
                            Label("导入 Logo...", systemImage: "photo.badge.plus")
                                .font(StudioTheme.TypeScale.caption.weight(.bold))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button("移除") {
                            viewModel.removeCornerLogo()
                        }
                        .font(StudioTheme.TypeScale.caption.weight(.bold))
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(viewModel.cornerLogoLoadPhase == .off)
                    }

                    if case .failed(let candidateURL, _) = viewModel.cornerLogoLoadPhase,
                       candidateURL != nil {
                        Button {
                            viewModel.retryCornerLogoLoad()
                        } label: {
                            Label("重试", systemImage: "arrow.clockwise")
                                .font(StudioTheme.TypeScale.caption.weight(.bold))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    Text(viewModel.cornerLogoLoadPhase.displayText)
                        .font(StudioTheme.caption())
                        .foregroundStyle(StudioTheme.textTertiary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous)
                .fill(StudioTheme.Surface.base)
        )
        .overlay(
            RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous)
                .stroke(StudioTheme.borderSubtle, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var logoPreview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                .fill(StudioTheme.Surface.raised)
                .frame(width: 86, height: 54)

            if let image = viewModel.cornerLogoImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(7)
                    .frame(width: 86, height: 54)
            } else {
                VStack(spacing: 3) {
                    Image(systemName: "building.2.crop.circle")
                        .font(StudioTheme.TypeScale.body.weight(.semibold))
                        .foregroundStyle(StudioTheme.textTertiary)
                    Text("无 Logo")
                        .font(StudioTheme.TypeScale.label.weight(.semibold))
                        .foregroundStyle(StudioTheme.textTertiary)
                }
                .frame(width: 86, height: 54)
            }
        }
        .accessibilityLabel(cornerLogoAccessibilityLabel)
    }

    private var cornerLogoAccessibilityLabel: String {
        switch viewModel.cornerLogoLoadPhase {
        case .off:
            "角标 Logo 已关闭"
        case .loading:
            "角标 Logo 正在加载"
        case .ready:
            "角标 Logo 已就绪"
        case .failed:
            "角标 Logo 加载失败"
        }
    }
}
