import Foundation

struct PresentationQueryService {
    var runAppleScript: (String, String) throws -> NSAppleEventDescriptor
    var scanOpenKeynoteFiles: () -> [String]

    init(
        runAppleScript: @escaping (String, String) throws -> NSAppleEventDescriptor,
        scanOpenKeynoteFiles: @escaping () -> [String]
    ) {
        self.runAppleScript = runAppleScript
        self.scanOpenKeynoteFiles = scanOpenKeynoteFiles
    }

    init(keynoteController: KeynoteController) {
        self.init(
            runAppleScript: { script, action in
                try AppleScriptRunner.run(script, action: action)
            },
            scanOpenKeynoteFiles: { [keynoteController] in
                keynoteController.scanOpenKeynoteFiles()
            }
        )
    }

    var queryOpenKeynoteFiles: () -> [String] {
        scanOpenKeynoteFiles
    }

    func scanKeynoteWindowNames() throws -> [String] {
        let script = """
        tell application "System Events"
            try
                get name of every window of application process "Keynote"
            on error
                return {}
            end try
        end tell
        """
        let result = try runAppleScript(script, "keynote.scan.windows")

        if result.numberOfItems > 0 {
            return (1...result.numberOfItems).compactMap { index in
                guard let name = result.atIndex(index)?.stringValue, !name.isEmpty else {
                    return nil
                }
                return name
            }
        }

        if let single = result.stringValue, !single.isEmpty {
            return [single]
        }

        return []
    }
}
