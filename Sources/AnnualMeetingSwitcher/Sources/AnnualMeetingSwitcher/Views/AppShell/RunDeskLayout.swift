import SwiftUI

@MainActor
struct RunDeskLayout: View {
    let avCoordinator: AVPlayerCoordinator
    let onEnterLive: @MainActor () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            LeftPanel()
                .frame(width: StudioTheme.directorRailWidth)
                .layoutPriority(1)

            ProgramMonitorView(avCoordinator: avCoordinator)
                .frame(minWidth: 500, idealWidth: 720, maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(3)

            LiveOpsPanel(onSwitchToLive: onEnterLive)
                .frame(width: StudioTheme.directorRailWidth)
                .layoutPriority(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 0)
    }
}
