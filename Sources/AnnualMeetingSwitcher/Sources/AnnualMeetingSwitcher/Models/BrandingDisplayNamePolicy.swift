import Foundation

enum BrandingDisplayNamePolicy {
    static let maximumCharacterCount = 32

    static func normalizedDisplayName(from rawValue: String) -> String {
        let mappedScalars = rawValue.unicodeScalars.map { scalar in
            isCollapsibleWhitespaceOrControl(scalar) ? UnicodeScalar(" ") : scalar
        }
        let mapped = String(String.UnicodeScalarView(mappedScalars))
        return mapped
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }

    static func effectiveDisplayName(for storedName: String) -> String {
        let normalized = normalizedDisplayName(from: storedName)
        return normalized.isEmpty ? AppConfiguration.appName : normalized
    }

    static func validationMessage(for draft: String) -> String? {
        let normalized = normalizedDisplayName(from: draft)
        guard normalized.count > maximumCharacterCount else { return nil }
        return "公司名称最多 32 个字符"
    }

    private static func isCollapsibleWhitespaceOrControl(_ scalar: UnicodeScalar) -> Bool {
        CharacterSet.whitespacesAndNewlines.contains(scalar)
            || scalar.value < 0x20
            || (scalar.value >= 0x7F && scalar.value <= 0x9F)
    }
}
