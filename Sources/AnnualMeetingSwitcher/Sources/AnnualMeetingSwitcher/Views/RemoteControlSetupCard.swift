import AppKit
import CoreImage
import SwiftUI

@MainActor
struct RemoteControlSetupCard: View {
    let state: RemoteControlSetupState
    let onEnable: @MainActor () -> Void
    let onDisable: @MainActor () -> Void
    let onCopyURL: @MainActor () -> Void

    @State private var didCopyURL = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("手机遥控")
                    .font(StudioTheme.statusLabel())
                    .foregroundStyle(StudioTheme.textTertiary)
                Spacer()
                StatusBadge(state.statusText, kind: state.status.badgeKind)
            }

            Button(action: toggleRemoteControl) {
                Label(state.isEnabled ? "关闭遥控" : "开启遥控", systemImage: state.isEnabled ? "stop.fill" : "qrcode")
                    .font(StudioTheme.TypeScale.caption.weight(.black))
                    .frame(maxWidth: .infinity)
                    .frame(height: LiveOpsLayoutMetrics.secondaryButtonHeight)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .tint(state.isEnabled ? StudioTheme.Tone.muted : StudioTheme.Action.primary)
            .focusable(false)

            if state.isEnabled, let pairingURL = state.pairingURL {
                pairingDetails(pairingURL: pairingURL)
            } else {
                disabledDetails
            }
            RemoteControlSetupDiagnosticList(
                messages: state.diagnosticMessages,
                isFailure: state.status == .failed
            )
        }
        .padding(LiveOpsLayoutMetrics.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous)
                .fill(StudioTheme.Surface.base.opacity(StudioTheme.Surface.Opacity.overlay))
        )
        .overlay(
            RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous)
                .stroke(state.status == .failed ? StudioTheme.Tone.live.opacity(0.28) : StudioTheme.borderSubtle, lineWidth: 1)
        )
    }

    private func pairingDetails(pairingURL: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let image = RemoteControlQRCodeImage.make(payload: pairingURL) {
                Image(nsImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(height: 118)
                    .padding(8)
                    .background(.white)
                    .clipShape(.rect(cornerRadius: StudioTheme.radiusS))
            }

            HStack(spacing: 6) {
                Text("局域网地址")
                    .font(StudioTheme.caption())
                    .foregroundStyle(StudioTheme.textSecondary)
                Spacer()
                Text(state.displayAddress ?? "未知")
                    .font(StudioTheme.caption().monospacedDigit())
                    .foregroundStyle(StudioTheme.textPrimary)
                    .lineLimit(1)
            }

            Button(action: copyPairingURL) {
                Label(didCopyURL ? "已复制" : "复制链接", systemImage: didCopyURL ? "checkmark" : "doc.on.doc")
                    .font(StudioTheme.TypeScale.caption.weight(.black))
                    .frame(maxWidth: .infinity)
                    .frame(height: LiveOpsLayoutMetrics.secondaryButtonHeight)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .focusable(false)
        }
    }

    private var disabledDetails: some View {
        Text(state.status == .failed ? "启动失败，请按提示排查" : "同一局域网手机扫码连接")
            .font(StudioTheme.caption())
            .foregroundStyle(state.status == .failed ? StudioTheme.Tone.live : StudioTheme.textSecondary)
            .lineLimit(2)
    }

    private func toggleRemoteControl() {
        if state.isEnabled {
            onDisable()
        } else {
            onEnable()
        }
    }

    private func copyPairingURL() {
        onCopyURL()
        didCopyURL = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            didCopyURL = false
        }
    }
}

private struct RemoteControlSetupDiagnosticList: View {
    let messages: [String]
    let isFailure: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(messages, id: \.self) { message in
                HStack(alignment: .top, spacing: 6) {
                    Circle()
                        .fill(isFailure ? StudioTheme.Tone.live : StudioTheme.textTertiary)
                        .frame(width: 4, height: 4)
                        .padding(.top, 6)
                    Text(message)
                        .font(StudioTheme.caption())
                        .foregroundStyle(isFailure ? StudioTheme.Tone.live : StudioTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.top, 2)
    }
}

enum RemoteControlQRCodeImage {
    static func make(payload: String) -> NSImage? {
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else {
            return nil
        }
        filter.setValue(Data(payload.utf8), forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")

        guard let outputImage = filter.outputImage else {
            return nil
        }

        let transformed = outputImage.transformed(by: CGAffineTransform(scaleX: 8, y: 8))
        let representation = NSCIImageRep(ciImage: transformed)
        let image = NSImage(size: representation.size)
        image.addRepresentation(representation)
        return image
    }
}

private extension RemoteControlSetupState.Status {
    var badgeKind: StudioTheme.StatusKind {
        switch self {
        case .disabled:
            return .idle
        case .enabled:
            return .ready
        case .failed:
            return .fail
        }
    }
}

#Preview {
    VStack {
        RemoteControlSetupCard(
            state: .disabled,
            onEnable: {},
            onDisable: {},
            onCopyURL: {}
        )
        RemoteControlSetupCard(
            state: RemoteControlSetupState(
                status: .enabled,
                host: "192.168.1.23",
                port: 41888,
                pairingURL: "http://192.168.1.23:41888/#token=preview"
            ),
            onEnable: {},
            onDisable: {},
            onCopyURL: {}
        )
    }
    .padding()
    .frame(width: 260)
    .background(StudioTheme.canvasBottom)
}
