import Foundation

enum PresentationQueryResultBuilder {
    static func makeProgramItems(
        from result: PresentationQueryResult,
        existingProgramItems: [ProgramItem]
    ) -> [ProgramItem] {
        makeProgramItems(
            openFilePaths: result.openFilePaths,
            windowNames: result.windowNames,
            existingProgramItems: existingProgramItems
        )
    }

    static func makeProgramItems(
        openFilePaths: [String],
        windowNames: [String],
        existingProgramItems: [ProgramItem]
    ) -> [ProgramItem] {
        if !openFilePaths.isEmpty {
            return fileBackedItems(from: openFilePaths, existingProgramItems: existingProgramItems)
        }

        return activeDeckItems(from: windowNames, existingProgramItems: existingProgramItems)
    }

    private static func fileBackedItems(
        from paths: [String],
        existingProgramItems: [ProgramItem]
    ) -> [ProgramItem] {
        var itemsToAdd: [ProgramItem] = []
        for path in paths {
            let url = URL(fileURLWithPath: path)
            let alreadyAdded = existingProgramItems.contains { $0.sourceURL == url }
                || itemsToAdd.contains { $0.sourceURL == url }
            guard !alreadyAdded else { continue }

            itemsToAdd.append(ProgramItem(
                title: url.deletingPathExtension().lastPathComponent,
                subtitle: "KEY",
                sourceURL: url
            ))
        }
        return itemsToAdd
    }

    private static func activeDeckItems(
        from windowNames: [String],
        existingProgramItems: [ProgramItem]
    ) -> [ProgramItem] {
        var itemsToAdd: [ProgramItem] = []
        for name in windowNames {
            let cleanName = PresentationWindowTitlePolicy.cleanedDocumentTitle(from: name)
            let alreadyAdded = existingProgramItems.contains { $0.title == cleanName }
                || itemsToAdd.contains { $0.title == cleanName }
            guard !alreadyAdded else { continue }

            itemsToAdd.append(ProgramItem(
                title: cleanName,
                subtitle: "KEY (活动)",
                sourceURL: nil
            ))
        }
        return itemsToAdd
    }
}
