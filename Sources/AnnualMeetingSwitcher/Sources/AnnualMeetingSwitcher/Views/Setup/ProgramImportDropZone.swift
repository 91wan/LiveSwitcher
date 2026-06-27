import SwiftUI
import UniformTypeIdentifiers

struct ProgramImportDropZone: View {
    @Binding var isDraggingOver: Bool
    let onAddProgramItems: ([ProgramItem]) -> Void
    let onAddProgramItem: (ProgramItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                addSourceButton(title: "视频 / 音频", systemName: "film.fill") {
                    openFilePicker(types: [.movie, .audio])
                }
                addSourceButton(title: "HTML", systemName: "globe.asia.australia.fill") {
                    openHTMLPicker()
                }
            }

            HStack(spacing: 8) {
                addSourceButton(title: "PPTX", systemName: "doc.richtext.fill") {
                    openPPTXPicker()
                }
                addSourceButton(title: "Keynote", systemName: "play.rectangle.fill") {
                    openKeynotePicker()
                }
            }

            Text("拖入文件，或使用上方按钮添加")
                .font(StudioTheme.caption())
                .foregroundStyle(StudioTheme.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                .fill(StudioTheme.Surface.base)
        )
        .overlay(
            RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                .stroke(isDraggingOver ? StudioTheme.borderActive : StudioTheme.borderSubtle, lineWidth: 1)
        )
        .onDrop(of: [.fileURL], isTargeted: $isDraggingOver) { providers in
            ProgramDropHandler.handleDrop(providers: providers, onAddProgramItem: onAddProgramItem)
        }
    }

    private func addSourceButton(
        title: String,
        systemName: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemName)
                .font(StudioTheme.TypeScale.caption.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: .infinity)
                .frame(height: 34)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .focusable(false)
    }

    private func openFilePicker(types: [UTType]) {
        DispatchQueue.main.async {
            let panel = NSOpenPanel()
            panel.title = "选择媒体文件"
            panel.allowsMultipleSelection = true
            panel.canChooseDirectories = false
            panel.allowedContentTypes = types

            guard panel.runModal() == .OK else { return }
            let items = panel.urls.map { url in
                ProgramItem(
                    title: url.deletingPathExtension().lastPathComponent,
                    subtitle: url.pathExtension.uppercased(),
                    sourceURL: url
                )
            }
            onAddProgramItems(items)
        }
    }

    private func openHTMLPicker() {
        DispatchQueue.main.async {
            let panel = NSOpenPanel()
            panel.title = "选择 HTML 文件"
            panel.allowsMultipleSelection = true
            panel.canChooseDirectories = false
            panel.allowedContentTypes = [UTType.html]

            guard panel.runModal() == .OK else { return }
            let items = panel.urls.map { url in
                ProgramItem(
                    title: url.deletingPathExtension().lastPathComponent,
                    subtitle: "HTML",
                    sourceURL: url
                )
            }
            onAddProgramItems(items)
        }
    }

    private func openPPTXPicker() {
        DispatchQueue.main.async {
            let panel = NSOpenPanel()
            panel.title = "选择 PowerPoint 文件"
            panel.allowsMultipleSelection = true
            panel.canChooseDirectories = false
            let pptxType = UTType("org.openxmlformats.presentationml.presentation") ?? .data
            let legacyPPTType = UTType(filenameExtension: "ppt") ?? .data
            panel.allowedContentTypes = [pptxType, legacyPPTType]

            guard panel.runModal() == .OK else { return }
            let items = panel.urls.map { url in
                ProgramItem(
                    title: url.deletingPathExtension().lastPathComponent,
                    subtitle: "PPTX",
                    sourceURL: url
                )
            }
            onAddProgramItems(items)
        }
    }

    private func openKeynotePicker() {
        DispatchQueue.main.async {
            let panel = NSOpenPanel()
            panel.title = "选择 Keynote 文件"
            panel.allowsMultipleSelection = true
            panel.canChooseDirectories = false
            panel.allowedContentTypes = [
                UTType("com.apple.iWork.Keynote.key"),
                UTType("com.apple.keynote.key"),
                UTType(filenameExtension: "keynote")
            ].compactMap { $0 }
            if panel.allowedContentTypes.isEmpty {
                panel.allowedContentTypes = [.data]
            }

            guard panel.runModal() == .OK else { return }
            let items = panel.urls.compactMap { url -> ProgramItem? in
                let ext = url.pathExtension.lowercased()
                guard ext == "key" || ext == "keynote" else { return nil }
                return ProgramItem(
                    title: url.deletingPathExtension().lastPathComponent,
                    subtitle: "KEY",
                    sourceURL: url
                )
            }
            onAddProgramItems(items)
        }
    }
}
