import SwiftUI

extension StudioTheme {
    enum TypeScale {
        static let display = Font.system(size: 28, weight: .bold)
        static let title = Font.system(size: 20, weight: .bold)
        static let heading = Font.system(size: 15, weight: .semibold)
        static let body = Font.system(size: 13, weight: .regular)
        static let caption = Font.system(size: 11, weight: .medium)
        static let mono = Font.system(size: 13, weight: .medium, design: .monospaced)
        static let monoCaption = Font.system(size: 10, weight: .bold, design: .monospaced)
        static let label = Font.system(size: 10, weight: .heavy, design: .rounded)
        static let numeric = Font.system(size: 18, weight: .black, design: .rounded)
    }

    static func titleLarge() -> Font { TypeScale.display }
    static func title() -> Font { TypeScale.title }
    static func sectionTitle() -> Font { TypeScale.heading }
    static func body() -> Font { TypeScale.body }
    static func caption() -> Font { TypeScale.caption }
    static func statusLabel() -> Font { TypeScale.label }
}
