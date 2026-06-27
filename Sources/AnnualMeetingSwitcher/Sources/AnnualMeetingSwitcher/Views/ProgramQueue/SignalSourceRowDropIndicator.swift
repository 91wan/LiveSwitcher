import SwiftUI

struct SignalSourceRowDropIndicator: View {
    let manualDropPlacement: ProgramQueueDropPlacement?

    var body: some View {
        VStack(spacing: 0) {
            dropIndicator(isActive: manualDropPlacement == .before)
            Spacer(minLength: 0)
            dropIndicator(isActive: manualDropPlacement == .after)
        }
        .padding(.horizontal, 6)
        .allowsHitTesting(false)
    }

    private func dropIndicator(isActive: Bool) -> some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(StudioTheme.Action.primary)
            .frame(height: 3)
            .opacity(isActive ? 1 : 0)
            .shadow(color: StudioTheme.Action.primary.opacity(isActive ? 0.45 : 0), radius: 5)
    }
}
