import Foundation
import UniformTypeIdentifiers

enum ProgramDropHandler {
    static func handleDrop(
        providers: [NSItemProvider],
        onAddProgramItem: @escaping (ProgramItem) -> Void
    ) -> Bool {
        var didRequestImport = false

        for provider in providers {
            guard provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) else {
                continue
            }
            didRequestImport = true
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                guard let url = FileDropSupport.decodeFileURL(from: item),
                      let programItem = FileDropSupport.importableProgramItem(from: url) else { return }
                DispatchQueue.main.async {
                    onAddProgramItem(programItem)
                }
            }
        }
        return didRequestImport
    }
}
