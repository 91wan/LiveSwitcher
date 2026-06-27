import SwiftUI

struct OverlayComposerPicker: View {
    let selectedKind: Binding<OverlayComposerKind>
    let onSelect: (OverlayComposerKind) -> Void

    var body: some View {
        Picker("叠层编辑", selection: selectedKind) {
            ForEach(OverlayComposerKind.allCases) { kind in
                Label(kind.pickerTitle, systemImage: kind.systemImage).tag(kind)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: selectedKind.wrappedValue) { _, newKind in
            onSelect(newKind)
        }
        .accessibilityLabel("叠层编辑")
    }
}
