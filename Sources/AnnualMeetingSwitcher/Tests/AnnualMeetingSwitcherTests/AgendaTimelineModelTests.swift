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

    func testScheduleStatusLocalizesPaceStates() {
        let item = ProgramItem(title: "Awards", scheduledStartAt: date(hour: 9, minute: 0), scheduledDuration: 30 * 60)

        let onSchedule = AgendaScheduleStatusModel.make(
            currentItem: item,
            switchedAt: date(hour: 9, minute: 0),
            now: date(hour: 9, minute: 7, second: 20)
        )
        XCTAssertEqual(onSchedule.text, "准点")
        XCTAssertEqual(onSchedule.kind, .ready)

        let behind = AgendaScheduleStatusModel.make(
            currentItem: item,
            switchedAt: date(hour: 9, minute: 5),
            now: date(hour: 9, minute: 10)
        )
        XCTAssertEqual(behind.text, "落后 5 分钟")
        XCTAssertEqual(behind.kind, .warn)

        let ahead = AgendaScheduleStatusModel.make(
            currentItem: item,
            switchedAt: date(hour: 8, minute: 57),
            now: date(hour: 9, minute: 8)
        )
        XCTAssertEqual(ahead.text, "提前 3 分钟")
        XCTAssertEqual(ahead.kind, .ready)
    }

    func testScheduledPromptDoesNotAutoCutAndIgnoresAlreadyPromptedItems() {
        let current = ProgramItem(id: UUID(), title: "Opening", scheduledStartAt: date(hour: 9, minute: 0), scheduledDuration: 15 * 60)
        let next = ProgramItem(id: UUID(), title: "CEO Speech", scheduledStartAt: date(hour: 9, minute: 15), scheduledDuration: 20 * 60)

        XCTAssertNil(AgendaReminderModel.prompt(
            isEnabled: false,
            programItems: [current, next],
            currentProgramItem: current,
            now: date(hour: 9, minute: 15),
            acknowledgedItemIDs: []
        ))

        let prompt = AgendaReminderModel.prompt(
            isEnabled: true,
            programItems: [current, next],
            currentProgramItem: current,
            now: date(hour: 9, minute: 15),
            acknowledgedItemIDs: []
        )
        XCTAssertEqual(prompt?.itemID, next.id)
        XCTAssertEqual(prompt?.title, "CEO Speech")
        XCTAssertEqual(prompt?.message, "已到计划时间：CEO Speech")

        XCTAssertNil(AgendaReminderModel.prompt(
            isEnabled: true,
            programItems: [current, next],
            currentProgramItem: current,
            now: date(hour: 9, minute: 15),
            acknowledgedItemIDs: [next.id]
        ))
    }

    func testScheduledPromptSkipsAgendaMarkers() {
        let current = ProgramItem(id: UUID(), title: "Opening", scheduledStartAt: date(hour: 9, minute: 0), scheduledDuration: 15 * 60)
        let marker = ProgramItem.agendaMarker(title: "Transition", scheduledStartAt: date(hour: 9, minute: 15))
        let next = ProgramItem(id: UUID(), title: "CEO Speech", scheduledStartAt: date(hour: 9, minute: 20), scheduledDuration: 20 * 60)

        let prompt = AgendaReminderModel.prompt(
            isEnabled: true,
            programItems: [current, marker, next],
            currentProgramItem: current,
            now: date(hour: 9, minute: 20),
            acknowledgedItemIDs: []
        )

        XCTAssertEqual(prompt?.itemID, marker.id)
        XCTAssertEqual(prompt?.title, "Transition")
        XCTAssertEqual(prompt?.kind, .marker)
    }

    func testAgendaReminderPromptsFirstScheduledItemWhenThereIsNoCurrentProgram() {
        let opening = ProgramItem(id: UUID(), title: "年会开场", scheduledStartAt: date(hour: 9, minute: 0), scheduledDuration: 15 * 60)
        let next = ProgramItem(id: UUID(), title: "领导致辞", scheduledStartAt: date(hour: 9, minute: 20), scheduledDuration: 20 * 60)

        let prompt = AgendaReminderModel.prompt(
            isEnabled: true,
            programItems: [opening, next],
            currentProgramItem: nil,
            now: date(hour: 9, minute: 1),
            acknowledgedItemIDs: []
        )

        XCTAssertEqual(prompt?.itemID, opening.id)
        XCTAssertEqual(prompt?.kind, .playableProgram)
        XCTAssertEqual(prompt?.message, "已到计划时间：年会开场")
    }

    func testAgendaReminderIncludesMarkersWithoutSwitchAction() {
        let opening = ProgramItem(id: UUID(), title: "年会开场", scheduledStartAt: date(hour: 9, minute: 0), scheduledDuration: 15 * 60)
        let marker = ProgramItem.agendaMarker(title: "茶歇", scheduledStartAt: date(hour: 9, minute: 15))
        let next = ProgramItem(id: UUID(), title: "抽奖", scheduledStartAt: date(hour: 9, minute: 20), scheduledDuration: 10 * 60)

        let prompt = AgendaReminderModel.prompt(
            isEnabled: true,
            programItems: [opening, marker, next],
            currentProgramItem: opening,
            now: date(hour: 9, minute: 16),
            acknowledgedItemIDs: []
        )

        XCTAssertEqual(prompt?.itemID, marker.id)
        XCTAssertEqual(prompt?.kind, .marker)
        XCTAssertEqual(prompt?.message, "议程提醒：茶歇")
    }

    func testAgendaReminderChoosesEarliestOverdueUnacknowledgedItem() {
        let current = ProgramItem(id: UUID(), title: "开场", scheduledStartAt: date(hour: 9, minute: 0), scheduledDuration: 5 * 60)
        let firstOverdue = ProgramItem(id: UUID(), title: "第一项", scheduledStartAt: date(hour: 9, minute: 5), scheduledDuration: 5 * 60)
        let secondOverdue = ProgramItem(id: UUID(), title: "第二项", scheduledStartAt: date(hour: 9, minute: 6), scheduledDuration: 5 * 60)

        let prompt = AgendaReminderModel.prompt(
            isEnabled: true,
            programItems: [current, secondOverdue, firstOverdue],
            currentProgramItem: current,
            now: date(hour: 9, minute: 10),
            acknowledgedItemIDs: [secondOverdue.id]
        )

        XCTAssertEqual(prompt?.itemID, firstOverdue.id)
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
        writer.isAgendaTimeReminderEnabled = true
        writer.saveData()

        let restored = SwitcherViewModel(loadPersistedData: true, enableSystemVolumeObserver: false, userDefaults: defaults)

        XCTAssertEqual(restored.programItems.count, 2)
        XCTAssertEqual(restored.programItems[0].scheduledStartAt, openingStart)
        XCTAssertEqual(restored.programItems[0].scheduledDuration, 15 * 60)
        XCTAssertEqual(restored.programItems[1].sourceKind, .agendaMarker)
        XCTAssertEqual(restored.programItems[1].scheduledStartAt, markerStart)
        XCTAssertEqual(restored.programItems[1].scheduledDuration, 10 * 60)
        XCTAssertTrue(restored.showAgendaTimeline)
        XCTAssertTrue(restored.isAgendaTimeReminderEnabled)
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

        XCTAssertTrue(model.chips.contains { $0.text == "落后 5 分钟" && $0.kind == .warn })
    }

    func testRunQueueSourcesExposeAgendaTimelineUIHooks() throws {
        let leftPanel = try sourceText("Sources/AnnualMeetingSwitcher/Views/LeftPanel.swift")
        let runQueue = [
            try sourceText("Views/ProgramQueue/SignalSourceRow.swift"),
            try sourceText("Views/ProgramQueue/SignalSourceRowHeader.swift")
        ].joined(separator: "\n")
        let liveMode = try sourceText("Sources/AnnualMeetingSwitcher/Views/LiveModeView.swift")

        XCTAssertTrue(leftPanel.contains("AgendaTimelineView"))
        XCTAssertTrue(leftPanel.contains("showAgendaTimeline"))
        XCTAssertTrue(leftPanel.contains("到点提醒"))
        XCTAssertTrue(leftPanel.contains("addAgendaMarker"))
        XCTAssertTrue(runQueue.contains("AgendaScheduleEditorPopover"))
        XCTAssertTrue(runQueue.contains("scheduledTimeText"))
        XCTAssertTrue(liveMode.contains("AgendaReminderHost"))
        XCTAssertTrue(liveMode.contains("TimelineView(.periodic"))
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
        try LiveSwitcherTests.sourceText(relativePath, filePath: #filePath)
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
