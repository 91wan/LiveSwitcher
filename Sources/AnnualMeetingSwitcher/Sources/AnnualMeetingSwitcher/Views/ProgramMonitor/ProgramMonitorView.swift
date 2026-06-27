import SwiftUI

// MARK: - Program Monitor

@MainActor
struct ProgramMonitorView: View {
    @Environment(SwitcherViewModel.self) var viewModel
    @ObservedObject var avCoordinator: AVPlayerCoordinator
    @State var isHoveringPreviewDeck = false
    var isLiveMode: Bool

    init(isLiveMode: Bool = false, avCoordinator: AVPlayerCoordinator) {
        self.isLiveMode = isLiveMode
        self._avCoordinator = ObservedObject(wrappedValue: avCoordinator)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isLiveMode ? 0 : 12) {
            if !isLiveMode {
                HStack(alignment: .firstTextBaseline) {
                    Text("主输出")
                        .font(StudioTheme.title())
                        .foregroundStyle(StudioTheme.textPrimary)
                    Text("监看")
                        .font(StudioTheme.caption())
                        .foregroundStyle(StudioTheme.textTertiary)
                    Spacer()
                }
            }

            previewDeckFrame

            if !isLiveMode {
                monitorUtilitiesStack
            }

            Spacer(minLength: 0)
        }
        .padding(isLiveMode ? 12 : 18)
        .studioCard(cornerRadius: 24)
    }
}
