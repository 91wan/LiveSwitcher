import Foundation

enum PresentationWindowTitlePolicy {
    static func cleanedDocumentTitle(from windowName: String) -> String {
        let extensionName = (windowName as NSString).pathExtension.lowercased()
        guard ["key", "keynote", "ppt", "pptx"].contains(extensionName) else {
            return windowName
        }
        return (windowName as NSString).deletingPathExtension
    }
}
