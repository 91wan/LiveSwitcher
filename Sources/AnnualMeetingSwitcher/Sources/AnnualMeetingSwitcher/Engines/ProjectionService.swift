import AppKit

struct ProjectionService {
    var externalScreenProvider: () -> NSScreen?
    var hasExternalDisplaySnapshot: Bool?

    init(
        externalScreenProvider: @escaping () -> NSScreen?,
        hasExternalDisplaySnapshot: Bool? = nil
    ) {
        self.externalScreenProvider = externalScreenProvider
        self.hasExternalDisplaySnapshot = hasExternalDisplaySnapshot
    }

    var hasExternalDisplay: Bool {
        if let hasExternalDisplaySnapshot {
            return hasExternalDisplaySnapshot
        }
        return externalScreenProvider() != nil
    }

    func targetScreen() -> NSScreen? {
        externalScreenProvider()
    }
}
