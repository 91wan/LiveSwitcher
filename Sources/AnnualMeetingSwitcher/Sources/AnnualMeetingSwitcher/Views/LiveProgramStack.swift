import SwiftUI

struct LiveProgramStack: View {
    @Environment(SwitcherViewModel.self) private var viewModel

    var body: some View {
        ProgramMonitorView(isLiveMode: true, avCoordinator: viewModel.avCoordinator)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityLabel("现场主输出监看")
    }
}

