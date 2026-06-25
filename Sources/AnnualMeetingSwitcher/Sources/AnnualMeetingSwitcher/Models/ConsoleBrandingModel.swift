import Foundation

enum ConsoleBrandingModel {
    static func title(brandName: String, mode: ConsoleMode, tab: MainConsoleTab) -> String {
        let brand = BrandingDisplayNamePolicy.effectiveDisplayName(for: brandName)
        let suffix = mode == .live ? "LIVE" : tab.chromeTitleSuffix
        return "\(brand) · \(suffix)"
    }
}
