import Foundation

extension ProgramRuntimeState {
    mutating func appendProgramItems(_ items: [ProgramItem]) {
        guard !items.isEmpty else { return }
        self.items.append(contentsOf: items)
    }

    mutating func removeProgramItem(id: UUID) {
        items.removeAll { $0.id == id }
        if currentID == id {
            currentID = nil
            currentDetachedItem = nil
            currentSwitchedAt = nil
        }
    }

    mutating func moveProgramItems(fromOffsets: [Int], toOffset: Int) {
        let validOffsets = Array(Set(fromOffsets))
            .filter { items.indices.contains($0) }
            .sorted()
        guard !validOffsets.isEmpty else { return }

        let movingItems = validOffsets.map { items[$0] }
        for index in validOffsets.reversed() {
            items.remove(at: index)
        }

        let removedBeforeDestination = validOffsets.filter { $0 < toOffset }.count
        let insertionIndex = min(max(0, toOffset - removedBeforeDestination), items.count)
        items.insert(contentsOf: movingItems, at: insertionIndex)
    }

    mutating func updateProgramItemSchedule(
        id: UUID,
        scheduledStartAt: Date?,
        scheduledDuration: TimeInterval?
    ) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].scheduledStartAt = scheduledStartAt
        items[index].scheduledDuration = scheduledDuration
    }

    mutating func appendAgendaMarker(title: String) {
        let start = items.last.flatMap { item -> Date? in
            guard let scheduledStartAt = item.scheduledStartAt,
                  let scheduledDuration = item.scheduledDuration
            else { return nil }
            return scheduledStartAt.addingTimeInterval(scheduledDuration)
        }
        items.append(ProgramItem.agendaMarker(title: title, scheduledStartAt: start))
    }

    mutating func replaceProgramQueueFromFacade(_ items: [ProgramItem]) {
        self.items = items
        if let currentID,
           !items.contains(where: { $0.id == currentID }),
           currentDetachedItem?.id != currentID {
            self.currentID = nil
            currentDetachedItem = nil
            currentSwitchedAt = nil
        }
    }
}
