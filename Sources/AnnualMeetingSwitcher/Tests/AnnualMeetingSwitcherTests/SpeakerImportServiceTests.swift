import Foundation
import XCTest
@testable import LiveSwitcher

@MainActor
final class SpeakerImportServiceTests: XCTestCase {
    func testParsesUTF8CSVWithThreeFieldHeaderAndQuotedFields() throws {
        let text = """
        name,role,organization
        "张三","主持人","示例科技"
        "李四, PhD","研发负责人","创新中心"

        王五, 财务总监, 财务部
        """

        let presets = try SpeakerImportService.parse(text: text)

        XCTAssertEqual(presets.map(\.name), ["张三", "李四, PhD", "王五"])
        XCTAssertEqual(presets.map(\.role), ["主持人", "研发负责人", "财务总监"])
        XCTAssertEqual(presets.map(\.organization), ["示例科技", "创新中心", "财务部"])
        XCTAssertEqual(presets.map(\.orderIndex), [0, 1, 2])
    }

    func testParsesLegacyTwoColumnRowsAsOrganization() throws {
        let text = """
        name\ttitle
        赵六\t示例学院
        钱七
        """

        let presets = try SpeakerImportService.parse(text: text)

        XCTAssertEqual(presets.map(\.name), ["赵六", "钱七"])
        XCTAssertEqual(presets.map(\.role), ["", ""])
        XCTAssertEqual(presets.map(\.organization), ["示例学院", ""])
    }

    func testDecodesChineseExcelGB18030Data() throws {
        let encoding = try XCTUnwrap(SpeakerImportService.chineseExcelEncoding)
        let data = try XCTUnwrap("姓名,职位,公司名称\n张三,主持人,示例科技\n".data(using: encoding))

        let presets = try SpeakerImportService.parse(data: data)

        XCTAssertEqual(presets.map(\.name), ["张三"])
        XCTAssertEqual(presets.map(\.role), ["主持人"])
        XCTAssertEqual(presets.map(\.organization), ["示例科技"])
    }

    func testMergeSkipsOverwritesOrImportsSameNameConflicts() throws {
        let existing = [
            try XCTUnwrap(LowerThirdPreset.make(name: "张三", role: "主持人", organization: "会务部", orderIndex: 0)),
            try XCTUnwrap(LowerThirdPreset.make(name: "王五", role: "财务", organization: "财务部", orderIndex: 1))
        ]
        let imported = [
            try XCTUnwrap(LowerThirdPreset.make(name: "张三", role: "董事长", organization: "集团", orderIndex: 0)),
            try XCTUnwrap(LowerThirdPreset.make(name: "李四", role: "研发", organization: "研发中心", orderIndex: 1))
        ]

        let skipped = SpeakerImportService.merge(imported: imported, into: existing, duplicatePolicy: .skipExisting)
        XCTAssertEqual(skipped.presets.map(\.name), ["张三", "王五", "李四"])
        XCTAssertEqual(skipped.presets.first { $0.name == "张三" }?.role, "主持人")
        XCTAssertEqual(skipped.presets.first { $0.name == "张三" }?.organization, "会务部")
        XCTAssertEqual(skipped.skippedNames, ["张三"])

        let overwritten = SpeakerImportService.merge(imported: imported, into: existing, duplicatePolicy: .overwriteExisting)
        XCTAssertEqual(overwritten.presets.map(\.name), ["张三", "王五", "李四"])
        XCTAssertEqual(overwritten.presets.first { $0.name == "张三" }?.role, "董事长")
        XCTAssertEqual(overwritten.presets.first { $0.name == "张三" }?.organization, "集团")
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
        XCTAssertTrue(viewModel.saveLowerThirdPreset(name: "张三", role: "主持人", organization: "会务部"))

        let imported = try SpeakerImportService.parse(text: "name,role,organization\n张三,董事长,集团\n李四,研发负责人,研发中心")
        let result = viewModel.importLowerThirdPresets(imported, duplicatePolicy: .overwriteExisting)

        XCTAssertEqual(result.overwrittenNames, ["张三"])
        XCTAssertEqual(viewModel.lowerThirdPresets.map(\.name), ["张三", "李四"])
        XCTAssertEqual(viewModel.lowerThirdPresets.first { $0.name == "张三" }?.role, "董事长")
        XCTAssertEqual(viewModel.lowerThirdPresets.first { $0.name == "张三" }?.organization, "集团")

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
            try XCTUnwrap(LowerThirdPreset.make(name: "张三", role: "主持人", organization: "示例科技", orderIndex: 0)),
            try XCTUnwrap(LowerThirdPreset.make(name: "李四, PhD", role: "研发 \"负责人\"", organization: "创新,中心", orderIndex: 1))
        ]

        let csv = SpeakerImportService.exportCSV(presets)

        XCTAssertTrue(csv.hasPrefix("name,role,organization\n"))
        XCTAssertTrue(csv.contains("张三,主持人,示例科技"))
        XCTAssertTrue(csv.contains("\"李四, PhD\",\"研发 \"\"负责人\"\"\",\"创新,中心\""))
    }
}
