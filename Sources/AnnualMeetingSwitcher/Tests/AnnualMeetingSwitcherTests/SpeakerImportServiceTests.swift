import Foundation
import XCTest
@testable import LiveSwitcher

@MainActor
final class SpeakerImportServiceTests: XCTestCase {
    func testParsesUTF8CSVWithOptionalHeaderAndQuotedFields() throws {
        let text = """
        name,title
        "张三","主持人"
        "李四, PhD","研发负责人"

        王五, 财务总监
        """

        let presets = try SpeakerImportService.parse(text: text)

        XCTAssertEqual(presets.map(\.name), ["张三", "李四, PhD", "王五"])
        XCTAssertEqual(presets.map(\.subtitle), ["主持人", "研发负责人", "财务总监"])
        XCTAssertEqual(presets.map(\.orderIndex), [0, 1, 2])
    }

    func testParsesTSVAndSingleColumnRows() throws {
        let text = """
        name\ttitle
        赵六\t培训讲师
        钱七
        """

        let presets = try SpeakerImportService.parse(text: text)

        XCTAssertEqual(presets.map(\.name), ["赵六", "钱七"])
        XCTAssertEqual(presets.map(\.subtitle), ["培训讲师", ""])
    }

    func testDecodesChineseExcelGB18030Data() throws {
        let encoding = try XCTUnwrap(SpeakerImportService.chineseExcelEncoding)
        let data = try XCTUnwrap("姓名,职务\n张三,主持人\n".data(using: encoding))

        let presets = try SpeakerImportService.parse(data: data)

        XCTAssertEqual(presets.map(\.name), ["张三"])
        XCTAssertEqual(presets.map(\.subtitle), ["主持人"])
    }

    func testMergeSkipsOverwritesOrImportsSameNameConflicts() throws {
        let existing = [
            try XCTUnwrap(LowerThirdPreset.make(name: "张三", subtitle: "主持人", orderIndex: 0)),
            try XCTUnwrap(LowerThirdPreset.make(name: "王五", subtitle: "财务", orderIndex: 1))
        ]
        let imported = [
            try XCTUnwrap(LowerThirdPreset.make(name: "张三", subtitle: "董事长", orderIndex: 0)),
            try XCTUnwrap(LowerThirdPreset.make(name: "李四", subtitle: "研发", orderIndex: 1))
        ]

        let skipped = SpeakerImportService.merge(imported: imported, into: existing, duplicatePolicy: .skipExisting)
        XCTAssertEqual(skipped.presets.map(\.name), ["张三", "王五", "李四"])
        XCTAssertEqual(skipped.presets.first { $0.name == "张三" }?.subtitle, "主持人")
        XCTAssertEqual(skipped.skippedNames, ["张三"])

        let overwritten = SpeakerImportService.merge(imported: imported, into: existing, duplicatePolicy: .overwriteExisting)
        XCTAssertEqual(overwritten.presets.map(\.name), ["张三", "王五", "李四"])
        XCTAssertEqual(overwritten.presets.first { $0.name == "张三" }?.subtitle, "董事长")
        XCTAssertEqual(overwritten.overwrittenNames, ["张三"])

        let importedAll = SpeakerImportService.merge(imported: imported, into: existing, duplicatePolicy: .importAll)
        XCTAssertEqual(importedAll.presets.map(\.name), ["张三", "王五", "张三", "李四"])
        XCTAssertTrue(importedAll.importedNames.contains("张三"))
    }

    func testViewModelImportsAndPersistsLowerThirdPresets() throws {
        let suite = "SpeakerImportServiceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let viewModel = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            userDefaults: defaults
        )
        XCTAssertTrue(viewModel.saveLowerThirdPreset(name: "张三", subtitle: "主持人"))

        let imported = try SpeakerImportService.parse(text: "张三,董事长\n李四,研发负责人")
        let result = viewModel.importLowerThirdPresets(imported, duplicatePolicy: .overwriteExisting)

        XCTAssertEqual(result.overwrittenNames, ["张三"])
        XCTAssertEqual(viewModel.lowerThirdPresets.map(\.name), ["张三", "李四"])
        XCTAssertEqual(viewModel.lowerThirdPresets.first { $0.name == "张三" }?.subtitle, "董事长")

        let reader = SwitcherViewModel(
            loadPersistedData: true,
            enableSystemVolumeObserver: false,
            userDefaults: defaults
        )
        XCTAssertEqual(reader.lowerThirdPresets.map(\.name), ["张三", "李四"])
        XCTAssertEqual(reader.lowerThirdPresets.map(\.orderIndex), [0, 1])
    }

    func testExportsCSVWithEscapedFields() throws {
        let presets = [
            try XCTUnwrap(LowerThirdPreset.make(name: "张三", subtitle: "主持人", orderIndex: 0)),
            try XCTUnwrap(LowerThirdPreset.make(name: "李四, PhD", subtitle: "研发 \"负责人\"", orderIndex: 1))
        ]

        let csv = SpeakerImportService.exportCSV(presets)

        XCTAssertTrue(csv.hasPrefix("name,title\n"))
        XCTAssertTrue(csv.contains("张三,主持人"))
        XCTAssertTrue(csv.contains("\"李四, PhD\",\"研发 \"\"负责人\"\"\""))
    }
}
