import AppKit

struct ProjectionService {
    var externalScreenProvider: () -> NSScreen?

    var hasExternalDisplay: Bool {
        externalScreenProvider() != nil
    }

    func targetScreen() -> NSScreen? {
        externalScreenProvider()
    }
}
