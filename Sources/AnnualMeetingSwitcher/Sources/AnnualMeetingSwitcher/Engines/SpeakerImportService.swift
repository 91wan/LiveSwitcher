import CoreFoundation
import Foundation

enum SpeakerImportError: Error, Equatable {
    case unsupportedEncoding
    case noValidRows
}

enum SpeakerImportDuplicatePolicy: Equatable {
    case skipExisting
    case overwriteExisting
    case importAll
}

struct SpeakerImportResult: Equatable {
    var presets: [LowerThirdPreset]
    var importedNames: [String]
    var skippedNames: [String]
    var overwrittenNames: [String]
}

enum SpeakerImportService {
    static var chineseExcelEncoding: String.Encoding? {
        let encoding = CFStringConvertEncodingToNSStringEncoding(
            CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
        )
        return String.Encoding(rawValue: encoding)
    }

    static func parse(data: Data) throws -> [LowerThirdPreset] {
        if let text = String(data: data, encoding: .utf8) {
            return try parse(text: text)
        }
        if let chineseExcelEncoding,
           let text = String(data: data, encoding: chineseExcelEncoding) {
            return try parse(text: text)
        }
        throw SpeakerImportError.unsupportedEncoding
    }

    static func parse(text: String) throws -> [LowerThirdPreset] {
        let rows = parseRows(text)
            .map { row in row.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } }
            .filter { row in row.contains { !$0.isEmpty } }

        let dataRows = rows.dropFirst(shouldSkipHeader(rows.first) ? 1 : 0)
        let presets = dataRows.enumerated().compactMap { index, row in
            LowerThirdPreset.make(
                name: row[safe: 0] ?? "",
                subtitle: row[safe: 1] ?? "",
                orderIndex: index
            )
        }

        guard !presets.isEmpty else {
            throw SpeakerImportError.noValidRows
        }
        return presets
    }

    static func merge(
        imported: [LowerThirdPreset],
        into existing: [LowerThirdPreset],
        duplicatePolicy: SpeakerImportDuplicatePolicy = .skipExisting
    ) -> SpeakerImportResult {
        var merged = LowerThirdPreset.normalized(existing)
        var importedNames: [String] = []
        var skippedNames: [String] = []
        var overwrittenNames: [String] = []

        for importedPreset in LowerThirdPreset.normalized(imported) {
            let importedKey = normalizedName(importedPreset.name)
            if let existingIndex = merged.firstIndex(where: { normalizedName($0.name) == importedKey }) {
                switch duplicatePolicy {
                case .skipExisting:
                    skippedNames.append(importedPreset.name)
                case .overwriteExisting:
                    let existingPreset = merged[existingIndex]
                    if let replacement = LowerThirdPreset.make(
                        id: existingPreset.id,
                        name: importedPreset.name,
                        subtitle: importedPreset.subtitle,
                        orderIndex: existingPreset.orderIndex
                    ) {
                        merged[existingIndex] = replacement
                        overwrittenNames.append(importedPreset.name)
                    }
                case .importAll:
                    if let appended = LowerThirdPreset.make(
                        id: importedPreset.id,
                        name: importedPreset.name,
                        subtitle: importedPreset.subtitle,
                        orderIndex: merged.count
                    ) {
                        merged.append(appended)
                        importedNames.append(importedPreset.name)
                    }
                }
            } else if let appended = LowerThirdPreset.make(
                id: importedPreset.id,
                name: importedPreset.name,
                subtitle: importedPreset.subtitle,
                orderIndex: merged.count
            ) {
                merged.append(appended)
                importedNames.append(importedPreset.name)
            }
        }

        return SpeakerImportResult(
            presets: LowerThirdPreset.normalized(merged),
            importedNames: importedNames,
            skippedNames: skippedNames,
            overwrittenNames: overwrittenNames
        )
    }

    static func exportCSV(_ presets: [LowerThirdPreset]) -> String {
        let rows = LowerThirdPreset.normalized(presets).map { preset in
            "\(escapeCSVField(preset.name)),\(escapeCSVField(preset.subtitle))"
        }
        return (["name,title"] + rows).joined(separator: "\n") + "\n"
    }

    private static func shouldSkipHeader(_ row: [String]?) -> Bool {
        guard let first = row?.first?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else {
            return false
        }
        return ["name", "speaker", "姓名", "嘉宾姓名"].contains(first)
    }

    private static func normalizedName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func escapeCSVField(_ field: String) -> String {
        let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
        if escaped.contains(",") || escaped.contains("\"") || escaped.contains("\n") || escaped.contains("\t") {
            return "\"\(escaped)\""
        }
        return escaped
    }

    private static func parseRows(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var isQuoted = false
        var iterator = Array(text).makeIterator()

        while let character = iterator.next() {
            if isQuoted {
                if character == "\"" {
                    if let next = iterator.next() {
                        if next == "\"" {
                            field.append("\"")
                        } else {
                            isQuoted = false
                            consumeUnquotedCharacter(next, field: &field, row: &row, rows: &rows)
                        }
                    } else {
                        isQuoted = false
                    }
                } else {
                    field.append(character)
                }
            } else if character == "\"" {
                isQuoted = true
            } else {
                consumeUnquotedCharacter(character, field: &field, row: &row, rows: &rows)
            }
        }

        row.append(field)
        rows.append(row)
        return rows
    }

    private static func consumeUnquotedCharacter(
        _ character: Character,
        field: inout String,
        row: inout [String],
        rows: inout [[String]]
    ) {
        switch character {
        case ",", "\t":
            row.append(field)
            field = ""
        case "\n":
            row.append(field)
            rows.append(row)
            row = []
            field = ""
        case "\r":
            break
        default:
            field.append(character)
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
