import SwiftUI

struct ProgramQueueDragHandle: View {
    let title: String
    let onDragChanged: (CGPoint) -> Void
    let onDragEnded: (CGPoint) -> Void

    var body: some View {
        Image(systemName: "line.3.horizontal")
            .font(StudioTheme.TypeScale.body.weight(.bold))
            .foregroundStyle(StudioTheme.textTertiary)
            .frame(width: 22, height: 34)
            .contentShape(Rectangle())
            .help("拖拽调整节目顺序")
            .accessibilityLabel("拖拽排序 \(title)")
            .gesture(
                DragGesture(minimumDistance: 2, coordinateSpace: .global)
                    .onChanged { value in
                        onDragChanged(value.location)
                    }
                    .onEnded { value in
                        onDragEnded(value.location)
                    }
            )
    }
}
