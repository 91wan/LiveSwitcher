import Foundation

enum ProgramQueueDropPlacement: Equatable {
    case before
    case after
}

struct ProgramQueueDropPlan: Equatable {
    let draggedID: UUID
    let targetID: UUID
    let placement: ProgramQueueDropPlacement

    struct Move: Equatable {
        let fromOffsets: IndexSet
        let toOffset: Int
    }

    func resolvedMove(in itemIDs: [UUID]) -> Move? {
        guard draggedID != targetID,
              let sourceIndex = itemIDs.firstIndex(of: draggedID),
              let targetIndex = itemIDs.firstIndex(of: targetID)
        else { return nil }

        let destination = placement == .before ? targetIndex : targetIndex + 1
        let move = Move(fromOffsets: IndexSet(integer: sourceIndex), toOffset: destination)
        guard resolvedOrder(in: itemIDs, move: move) != itemIDs else { return nil }
        return move
    }

    func resolvedOrder(in itemIDs: [UUID]) -> [UUID]? {
        guard let move = resolvedMove(in: itemIDs) else { return nil }
        return resolvedOrder(in: itemIDs, move: move)
    }

    private func resolvedOrder(in itemIDs: [UUID], move: Move) -> [UUID] {
        var next = itemIDs
        let sourceIndexes = Array(move.fromOffsets).sorted()
        let moving = sourceIndexes.map { next[$0] }
        for index in sourceIndexes.reversed() {
            next.remove(at: index)
        }
        let removedBeforeDestination = sourceIndexes.filter { $0 < move.toOffset }.count
        let insertionIndex = min(max(0, move.toOffset - removedBeforeDestination), next.count)
        next.insert(contentsOf: moving, at: insertionIndex)
        return next
    }
}
