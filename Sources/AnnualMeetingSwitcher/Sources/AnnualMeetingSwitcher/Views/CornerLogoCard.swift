import SwiftUI
import UniformTypeIdentifiers

private enum CornerLogoImportService {
    @MainActor
    static func presentPicker(viewModel: SwitcherViewModel) {
        let panel = NSOpenPanel()
        panel.title = "导入品牌 Logo"
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
    @State private var companyNameDraft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            companyNameEditor
            Divider()
                .overlay(StudioTheme.borderSubtle)
            logoControls
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
        .onAppear {
            companyNameDraft = viewModel.companyDisplayName
        }
        .onChange(of: viewModel.companyDisplayName) { _, newValue in
            companyNameDraft = newValue
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("品牌标识")
                    .font(StudioTheme.sectionTitle())
                    .foregroundStyle(StudioTheme.textPrimary)
                Text("输出画面与控制台标题使用的品牌信息")
                    .font(StudioTheme.caption())
                    .foregroundStyle(StudioTheme.textTertiary)
            }
            Spacer()
            logoStatusBadge
        }
    }

    private var companyNameEditor: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("公司名称")
                .font(StudioTheme.TypeScale.label.weight(.semibold))
                .foregroundStyle(StudioTheme.textSecondary)

            TextField("公司名称", text: $companyNameDraft)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1)

            HStack(spacing: 8) {
                Button("应用") {
                    applyCompanyNameDraft()
                }
                .font(StudioTheme.TypeScale.caption.weight(.bold))
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(companyNameValidationMessage != nil)

                Button("恢复默认") {
                    companyNameDraft = ""
                    viewModel.companyDisplayName = ""
                }
                .font(StudioTheme.TypeScale.caption.weight(.bold))
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer(minLength: 0)
            }

            Text(companyNameFooterText)
                .font(StudioTheme.caption())
                .foregroundStyle(companyNameValidationMessage == nil ? StudioTheme.textTertiary : StudioTheme.Action.danger)
                .lineLimit(1)
        }
    }

    private var logoControls: some View {
        @Bindable var viewModel = viewModel

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                logoPreview
                Toggle("显示 Logo", isOn: $viewModel.isCornerLogoVisible)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .font(StudioTheme.TypeScale.caption.weight(.semibold))
                    .disabled(!hasLogo)
                Spacer(minLength: 0)
            }

            Picker("位置", selection: $viewModel.cornerLogoPosition) {
                ForEach(CornerLogoPosition.allCases, id: \.self) { position in
                    Text(position.displayName)
                        .tag(position)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .disabled(!hasLogo)
            .help("选择 Logo 显示角落")

            HStack(spacing: 8) {
                Button {
                    CornerLogoImportService.presentPicker(viewModel: self.viewModel)
                } label: {
                    Label("导入 Logo...", systemImage: "photo.badge.plus")
                        .font(StudioTheme.TypeScale.caption.weight(.bold))
                        .lineLimit(1)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("移除") {
                    self.viewModel.removeCornerLogo()
                }
                .font(StudioTheme.TypeScale.caption.weight(.bold))
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(viewModel.cornerLogoLoadPhase == .empty)
            }

            if case .failed(let candidateURL, _) = viewModel.cornerLogoLoadPhase,
               candidateURL != nil {
                Button {
                    self.viewModel.retryCornerLogoLoad()
                } label: {
                    Label("重试", systemImage: "arrow.clockwise")
                        .font(StudioTheme.TypeScale.caption.weight(.bold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Text(logoStatusText)
                .font(StudioTheme.caption())
                .foregroundStyle(StudioTheme.textTertiary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    @ViewBuilder
    private var logoPreview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                .fill(StudioTheme.Surface.raised)
                .frame(width: 72, height: 44)

            if let image = viewModel.cornerLogoImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(6)
                    .frame(width: 72, height: 44)
            } else {
                VStack(spacing: 3) {
                    Image(systemName: "building.2.crop.circle")
                        .font(StudioTheme.TypeScale.body.weight(.semibold))
                        .foregroundStyle(StudioTheme.textTertiary)
                    Text("无 Logo")
                        .font(StudioTheme.TypeScale.label.weight(.semibold))
                        .foregroundStyle(StudioTheme.textTertiary)
                }
                .frame(width: 72, height: 44)
            }
        }
        .accessibilityLabel(cornerLogoAccessibilityLabel)
    }

    private var logoStatusBadge: some View {
        switch viewModel.cornerLogoLoadPhase {
        case .empty:
            StatusBadge("未导入", kind: .idle)
        case .loading:
            StatusBadge("加载中", kind: .warn)
        case .ready:
            StatusBadge(viewModel.isCornerLogoVisible ? "已显示" : "已隐藏", kind: .ready)
        case .failed:
            StatusBadge(hasLogo ? "已保留" : "加载失败", kind: hasLogo ? .warn : .fail)
        }
    }

    private var logoStatusText: String {
        switch viewModel.cornerLogoLoadPhase {
        case .empty:
            "未导入"
        case .loading:
            "加载中"
        case .ready:
            viewModel.isCornerLogoVisible
                ? "已显示 · \(viewModel.cornerLogoPosition.shortLabel)"
                : "已隐藏"
        case .failed(_, let reason):
            hasLogo ? "换图失败，当前 Logo 已保留" : "加载失败：\(reason.displayText)"
        }
    }

    private var cornerLogoAccessibilityLabel: String {
        switch viewModel.cornerLogoLoadPhase {
        case .empty:
            "品牌 Logo 未导入"
        case .loading:
            "品牌 Logo 正在加载"
        case .ready:
            viewModel.isCornerLogoVisible ? "品牌 Logo 已显示" : "品牌 Logo 已隐藏"
        case .failed:
            hasLogo ? "品牌 Logo 换图失败，当前 Logo 已保留" : "品牌 Logo 加载失败"
        }
    }

    private var hasLogo: Bool {
        viewModel.cornerLogoURL != nil && viewModel.cornerLogoImage != nil
    }

    private var normalizedCompanyNameDraft: String {
        BrandingDisplayNamePolicy.normalizedDisplayName(from: companyNameDraft)
    }

    private var companyNameValidationMessage: String? {
        BrandingDisplayNamePolicy.validationMessage(for: companyNameDraft)
    }

    private var companyNameFooterText: String {
        companyNameValidationMessage ?? "留空时显示 \(AppConfiguration.appName)"
    }

    private func applyCompanyNameDraft() {
        guard companyNameValidationMessage == nil else { return }
        let normalized = normalizedCompanyNameDraft
        companyNameDraft = normalized
        viewModel.companyDisplayName = normalized
    }
}
