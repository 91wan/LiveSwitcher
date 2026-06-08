import XCTest
@testable import LiveSwitcher

final class ProgramSourceAvailabilityPolicyTests: XCTestCase {
    func testMediaURLRequiresExistingFile() {
        let url = URL(fileURLWithPath: "/tmp/video.mp4")

        XCTAssertNil(result(for: item(subtitle: "VIDEO", url: url), existingPaths: [url.path]).unavailableReason)
    }

    func testHTMLURLRequiresExistingFile() {
        let url = URL(fileURLWithPath: "/tmp/page.html")

        XCTAssertNil(result(for: item(subtitle: "HTML", url: url), existingPaths: [url.path]).unavailableReason)
    }

    func testKeynoteURLRequiresExistingFile() {
        let url = URL(fileURLWithPath: "/tmp/deck.key")

        XCTAssertNil(result(for: item(subtitle: "KEY", url: url), existingPaths: [url.path]).unavailableReason)
    }

    func testPPTXURLRequiresExistingFile() {
        let url = URL(fileURLWithPath: "/tmp/deck.pptx")

        XCTAssertNil(result(for: item(subtitle: "PPTX", url: url), existingPaths: [url.path]).unavailableReason)
    }

    func testMissingMediaURLDetectedFromVideoSubtitle() {
        let availability = result(for: item(subtitle: "VIDEO"))

        XCTAssertEqual(availability.kind, .media)
        XCTAssertEqual(availability.unavailableReason, .sourceURLMissing)
    }

    func testMissingMediaURLDetectedFromAudioSubtitle() {
        let availability = result(for: item(subtitle: "AUDIO"))

        XCTAssertEqual(availability.kind, .media)
        XCTAssertEqual(availability.unavailableReason, .sourceURLMissing)
    }

    func testMissingHTMLURLDetectedFromHTMLSubtitle() {
        let availability = result(for: item(subtitle: "HTML"))

        XCTAssertEqual(availability.kind, .html)
        XCTAssertEqual(availability.unavailableReason, .sourceURLMissing)
    }

    func testMissingPPTURLDetectedFromPPTSubtitle() {
        let availability = result(for: item(subtitle: "PPT slides"))

        XCTAssertEqual(availability.kind, .pptx)
        XCTAssertEqual(availability.unavailableReason, .sourceURLMissing)
    }

    func testActiveDeckDoesNotRequireFile() {
        let availability = result(for: item(subtitle: "KEY"))

        XCTAssertEqual(availability.kind, .activeDeck)
        XCTAssertNil(availability.unavailableReason)
    }

    func testAgendaMarkerDoesNotRequireFile() {
        let availability = result(for: .agendaMarker(title: "Break"))

        XCTAssertEqual(availability.kind, .agendaMarker)
        XCTAssertNil(availability.unavailableReason)
    }

    func testUnsupportedWithoutFileBackedLabelDoesNotRequireFile() {
        let availability = result(for: item(subtitle: "TXT"))

        XCTAssertEqual(availability.kind, .unsupported)
        XCTAssertNil(availability.unavailableReason)
    }

    func testMissingFileReportsFileMissing() {
        let url = URL(fileURLWithPath: "/tmp/missing.mp4")
        let availability = result(for: item(subtitle: "VIDEO", url: url))

        XCTAssertEqual(availability.kind, .media)
        XCTAssertEqual(availability.unavailableReason, .fileMissing)
    }

    func testSupportLabelsMatchLegacyValues() {
        XCTAssertEqual(ProgramSourceAvailabilityPolicy.supportLabel(for: .media), "media")
        XCTAssertEqual(ProgramSourceAvailabilityPolicy.supportLabel(for: .html), "html")
        XCTAssertEqual(ProgramSourceAvailabilityPolicy.supportLabel(for: .keynote), "keynote")
        XCTAssertEqual(ProgramSourceAvailabilityPolicy.supportLabel(for: .pptx), "pptx")
        XCTAssertEqual(ProgramSourceAvailabilityPolicy.supportLabel(for: .activeDeck), "activeDeck")
        XCTAssertEqual(ProgramSourceAvailabilityPolicy.supportLabel(for: .agendaMarker), "agendaMarker")
        XCTAssertEqual(ProgramSourceAvailabilityPolicy.supportLabel(for: .unsupported), "unsupported")
    }

    func testPolicyDoesNotReferenceSwitcherViewModel() throws {
        XCTAssertFalse(try policySource().contains("SwitcherViewModel"))
    }

    func testPolicyDoesNotRecordSupport() throws {
        XCTAssertFalse(try policySource().contains("recordSupportEvent"))
    }

    func testPolicyDoesNotShowAutomationNotice() throws {
        let source = try policySource()

        XCTAssertFalse(source.contains("showAutomationRuntimeNotice"))
        XCTAssertFalse(source.contains("FileManager.default"))
    }

    private func result(
        for item: ProgramItem,
        existingPaths: Set<String> = []
    ) -> ProgramSourceAvailabilityResult {
        ProgramSourceAvailabilityPolicy.availability(
            for: item,
            fileExists: { existingPaths.contains($0) }
        )
    }

    private func item(subtitle: String, url: URL? = nil) -> ProgramItem {
        ProgramItem(title: subtitle, subtitle: subtitle, sourceURL: url)
    }

    private func policySource() throws -> String {
        try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Models/ProgramSourceAvailabilityPolicy.swift"
        )
    }
}
