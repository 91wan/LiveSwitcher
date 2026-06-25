import XCTest
@testable import LiveSwitcher

final class AgendaTimelineModelTests: XCTestCase {
    func testProgramItemScheduleDefaultsAreNil() {
        let item = ProgramItem(title: "Opening", subtitle: "MP4")

        XCTAssertNil(item.scheduledStartAt)
        XCTAssertNil(item.scheduledDuration)
        XCTAssertFalse(item.isAgendaMarker)
    }

    func testTimelineInfersMissingStartFromPreviousEnd() {
        let openingStart = date(hour: 9, minute: 0)
        let keynoteStart = date(hour: 9, minute: 15)
        let items = [
            ProgramItem(
                title: "Opening",
                subtitle: "MP4",
                sourceURL: URL(fileURLWithPath: "/tmp/opening.mp4"),
                scheduledStartAt: openingStart,
                scheduledDuration: 15 * 60
            ),
            ProgramItem(
                title: "Keynote",
                subtitle: "PPTX",
                sourceURL: URL(fileURLWithPath: "/tmp/keynote.pptx"),
                scheduledDuration: 30 * 60
            )
        ]

        let timeline = AgendaTimelineModel.make(items: items, dayAnchor: openingStart)

        XCTAssertEqual(timeline.entries.map(\.title), ["Opening", "Keynote"])
        XCTAssertEqual(timeline.entries[0].scheduledStartAt, openingStart)
        XCTAssertEqual(timeline.entries[0].scheduledEndAt, keynoteStart)
        XCTAssertFalse(timeline.entries[0].isStartInferred)
        XCTAssertEqual(timeline.entries[1].scheduledStartAt, keynoteStart)
        XCTAssertEqual(timeline.entries[1].scheduledEndAt, date(hour: 9, minute: 45))
        XCTAssertTrue(timeline.entries[1].isStartInferred)
    }

    func testTimelineUsesDefaultDurationForItemsWithoutDuration() {
        let start = date(hour: 10, minute: 0)
        let item = ProgramItem(title: "CEO Speech", scheduledStartAt: start)

        let timeline = AgendaTimelineModel.make(items: [item], dayAnchor: start, defaultDuration: 20 * 60)

        XCTAssertEqual(timeline.entries.single?.scheduledEndAt, date(hour: 10, minute: 20))
        XCTAssertEqual(timeline.entries.single?.durationMinutes, 20)
    }

    func testAgendaMarkerIsNonPlayableAndDisplayable() {
        let marker = ProgramItem.agendaMarker(title: "Tea Break", scheduledStartAt: date(hour: 10, minute: 0), durationMinutes: 15)

        XCTAssertTrue(marker.isAgendaMarker)
        XCTAssertEqual(marker.sourceKind, .agendaMarker)
        XCTAssertEqual(marker.displaySourceLabel, "标记")
        XCTAssertFalse(marker.sourceKind.isImportableFile)
        XCTAssertFalse(marker.supportsSeeking)
    }

    func testScheduleStatusOnScheduleBehindAndAhead() {
        let item = ProgramItem(title: "Awards", scheduledStartAt: date(hour: 9, minute: 0), scheduledDuration: 30 * 60)

        let onSchedule = AgendaScheduleStatusModel.make(
            currentItem: item,
            switchedAt: date(hour: 9, minute: 0),
            now: date(hour: 9, minute: 7, second: 20)
        )
        XCTAssertEqual(onSchedule.text, "On schedule")
        XCTAssertEqual(onSchedule.kind, .ready)

        let behind = AgendaScheduleStatusModel.make(
            currentItem: item,
            switchedAt: date(hour: 9, minute: 5),
            now: date(hour: 9, minute: 10)
        )
        XCTAssertEqual(behind.text, "Behind by 5 min")
        XCTAssertEqual(behind.kind, .warn)

        let ahead = AgendaScheduleStatusModel.make(
            currentItem: item,
            switchedAt: date(hour: 8, minute: 57),
            now: date(hour: 9, minute: 8)
        )
        XCTAssertEqual(ahead.text, "Ahead 3 min")
        XCTAssertEqual(ahead.kind, .ready)
    }

    func testScheduledPromptDoesNotAutoCutAndIgnoresAlreadyPromptedItems() {
        let current = ProgramItem(id: UUID(), title: "Opening", scheduledStartAt: date(hour: 9, minute: 0), scheduledDuration: 15 * 60)
        let next = ProgramItem(id: UUID(), title: "CEO Speech", scheduledStartAt: date(hour: 9, minute: 15), scheduledDuration: 20 * 60)

        XCTAssertNil(AgendaAutoAdvanceModel.prompt(
            isEnabled: false,
            programItems: [current, next],
            currentProgramItem: current,
            now: date(hour: 9, minute: 15),
            promptedItemIDs: []
        ))

        let prompt = AgendaAutoAdvanceModel.prompt(
            isEnabled: true,
            programItems: [current, next],
            currentProgramItem: current,
            now: date(hour: 9, minute: 15),
            promptedItemIDs: []
        )
        XCTAssertEqual(prompt?.itemID, next.id)
        XCTAssertEqual(prompt?.title, "CEO Speech")
        XCTAssertEqual(prompt?.message, "Scheduled time reached. Switch to CEO Speech?")

        XCTAssertNil(AgendaAutoAdvanceModel.prompt(
            isEnabled: true,
            programItems: [current, next],
            currentProgramItem: current,
            now: date(hour: 9, minute: 15),
            promptedItemIDs: [next.id]
        ))
    }

    func testScheduledPromptSkipsAgendaMarkers() {
        let current = ProgramItem(id: UUID(), title: "Opening", scheduledStartAt: date(hour: 9, minute: 0), scheduledDuration: 15 * 60)
        let marker = ProgramItem.agendaMarker(title: "Transition", scheduledStartAt: date(hour: 9, minute: 15))
        let next = ProgramItem(id: UUID(), title: "CEO Speech", scheduledStartAt: date(hour: 9, minute: 20), scheduledDuration: 20 * 60)

        let prompt = AgendaAutoAdvanceModel.prompt(
            isEnabled: true,
            programItems: [current, marker, next],
            currentProgramItem: current,
            now: date(hour: 9, minute: 20),
            promptedItemIDs: []
        )

        XCTAssertEqual(prompt?.itemID, next.id)
        XCTAssertEqual(prompt?.title, "CEO Speech")
    }

    func testLiveCutBusSkipsNonPlayableAgendaMarkers() {
        let current = ProgramItem(id: UUID(), title: "Opening", sourceURL: URL(fileURLWithPath: "/tmp/opening.mp4"))
        let marker = ProgramItem.agendaMarker(title: "Tea Break", scheduledStartAt: date(hour: 9, minute: 15))
        let next = ProgramItem(id: UUID(), title: "Awards", sourceURL: URL(fileURLWithPath: "/tmp/awards.mp4"))

        let model = LiveCutBusModel.make(programItems: [current, marker, next], currentProgramItem: current)

        XCTAssertTrue(model.canTakeNext)
        XCTAssertEqual(model.nextIndex, 2)
        XCTAssertEqual(model.nextTitle, "Awards")
    }

    func testProgramQueueStoreSkipsAgendaMarkersForNextPlayableIndex() {
        let marker = ProgramItem.agendaMarker(title: "Doors Open", scheduledStartAt: date(hour: 8, minute: 45))
        let opening = ProgramItem(id: UUID(), title: "Opening", sourceURL: URL(fileURLWithPath: "/tmp/opening.mp4"))
        let breakMarker = ProgramItem.agendaMarker(title: "Break", scheduledStartAt: date(hour: 9, minute: 15))
        let awards = ProgramItem(id: UUID(), title: "Awards", sourceURL: URL(fileURLWithPath: "/tmp/awards.mp4"))

        XCTAssertEqual(
            ProgramQueueStore.nextPlayableIndexAfterCurrent(current: nil, in: [marker, opening, breakMarker, awards]),
            1
        )
        XCTAssertEqual(
            ProgramQueueStore.nextPlayableIndexAfterCurrent(current: opening, in: [marker, opening, breakMarker, awards]),
            3
        )
        XCTAssertNil(ProgramQueueStore.nextPlayableIndexAfterCurrent(current: awards, in: [marker, opening, breakMarker, awards]))
    }

    @MainActor
    func testProgramSchedulePersistenceRoundTripsThroughUserDefaults() {
        let defaults = isolatedDefaults()
        let mediaURL = temporaryFile(named: "opening.mp4")
        let openingStart = date(hour: 9, minute: 0)
        let markerStart = date(hour: 9, minute: 15)
        let writer = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false, userDefaults: defaults)
        writer.addProgramItem(
            ProgramItem(
                title: "Opening",
                subtitle: "MP4",
                sourceURL: mediaURL,
                scheduledStartAt: openingStart,
                scheduledDuration: 15 * 60
            )
        )
        writer.addProgramItem(
            ProgramItem.agendaMarker(
                title: "Tea Break",
                scheduledStartAt: markerStart,
                durationMinutes: 10
            )
        )
        writer.showAgendaTimeline = true
        writer.autoAdvanceAtScheduledTime = true
        writer.saveData()

        let restored = SwitcherViewModel(loadPersistedData: true, enableSystemVolumeObserver: false, userDefaults: defaults)

        XCTAssertEqual(restored.programItems.count, 2)
        XCTAssertEqual(restored.programItems[0].scheduledStartAt, openingStart)
        XCTAssertEqual(restored.programItems[0].scheduledDuration, 15 * 60)
        XCTAssertEqual(restored.programItems[1].sourceKind, .agendaMarker)
        XCTAssertEqual(restored.programItems[1].scheduledStartAt, markerStart)
        XCTAssertEqual(restored.programItems[1].scheduledDuration, 10 * 60)
        XCTAssertTrue(restored.showAgendaTimeline)
        XCTAssertTrue(restored.autoAdvanceAtScheduledTime)
    }

    func testLiveRuntimeStatusIncludesAgendaScheduleChip() {
        let item = ProgramItem(
            title: "Awards",
            scheduledStartAt: date(hour: 9, minute: 0),
            scheduledDuration: 30 * 60
        )
        let snapshot = LivePreflightSnapshot.fixture(
            isBroadcasting: true,
            currentProgramTitle: "Awards",
            currentProgramScheduledStartAt: item.scheduledStartAt,
            currentProgramScheduledDuration: item.scheduledDuration,
            currentProgramSwitchedAt: date(hour: 9, minute: 5),
            scheduleNow: date(hour: 9, minute: 10)
        )

        let model = LiveRuntimeStatusModel.make(checks: [], snapshot: snapshot)

        XCTAssertTrue(model.chips.contains { $0.text == "Behind by 5 min" && $0.kind == .warn })
    }

    func testRunQueueSourcesExposeAgendaTimelineUIHooks() throws {
        let leftPanel = try sourceText("Sources/AnnualMeetingSwitcher/Views/LeftPanel.swift")
        let runQueue = try sourceText("Sources/AnnualMeetingSwitcher/Views/RunQueueView.swift")
        let liveMode = try sourceText("Sources/AnnualMeetingSwitcher/Views/LiveModeView.swift")

        XCTAssertTrue(leftPanel.contains("AgendaTimelineView"))
        XCTAssertTrue(leftPanel.contains("showAgendaTimeline"))
        XCTAssertTrue(leftPanel.contains("autoAdvanceAtScheduledTime"))
        XCTAssertTrue(leftPanel.contains("addAgendaMarker"))
        XCTAssertTrue(runQueue.contains("AgendaScheduleEditorPopover"))
        XCTAssertTrue(runQueue.contains("scheduledTimeText"))
        XCTAssertTrue(liveMode.contains("agendaAutoAdvancePrompt()"))
    }

    private func date(hour: Int, minute: Int, second: Int = 0) -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = 2026
        components.month = 5
        components.day = 25
        components.hour = hour
        components.minute = minute
        components.second = second
        return components.date!
    }

    private func isolatedDefaults() -> UserDefaults {
        let suiteName = "LiveSwitcher.AgendaTimelineModelTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func temporaryFile(named fileName: String) -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("LiveSwitcherAgendaTimelineTests-\(UUID().uuidString)")
            .appendingPathComponent(fileName)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: url.path, contents: Data("fixture".utf8))
        return url
    }

    private func sourceText(_ relativePath: String) throws -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }
}

private extension Array {
    var single: Element? {
        count == 1 ? first : nil
    }
}

private extension LivePreflightSnapshot {
    static func fixture(
        isBroadcasting: Bool,
        currentProgramTitle: String?,
        currentProgramScheduledStartAt: Date?,
        currentProgramScheduledDuration: TimeInterval?,
        currentProgramSwitchedAt: Date?,
        scheduleNow: Date
    ) -> LivePreflightSnapshot {
        LivePreflightSnapshot(
            appVersion: "0.0.0",
            hasExternalDisplay: true,
            isBroadcasting: isBroadcasting,
            broadcastSafetyNotice: nil,
            programItemCount: currentProgramTitle == nil ? 0 : 1,
            currentProgramTitle: currentProgramTitle,
            currentProgramSource: currentProgramTitle == nil ? nil : "Media",
            currentProgramScheduledStartAt: currentProgramScheduledStartAt,
            currentProgramScheduledDuration: currentProgramScheduledDuration,
            currentProgramSwitchedAt: currentProgramSwitchedAt,
            scheduleNow: scheduleNow,
            bgmItemCount: 0,
            isBGMPlaying: false,
            isBGMAudioTakeoverActive: false,
            isSpeakerMode: false,
            isPanicMode: false,
            isPageInterceptEnabled: false,
            activeOverlayCount: 0,
            activeOverlayKinds: [],
            countdownRemainingSeconds: nil,
            wallpaperCount: 1,
            autoPlayNextVideoOnEnd: false,
            effectiveMediaVolume: 0.5,
            effectiveBGMVolume: 0.4
        )
    }
}
