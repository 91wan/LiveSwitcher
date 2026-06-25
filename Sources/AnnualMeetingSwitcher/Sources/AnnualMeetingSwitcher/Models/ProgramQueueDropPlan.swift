import CoreGraphics
import Foundation

enum ProgramQueueDropPlacement: Equatable {
    case before
    case after
}

struct ProgramQueueDropPreview: Equatable {
    let targetID: UUID
    let placement: ProgramQueueDropPlacement
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

enum ProgramQueueDropTargetResolver {
    static let defaultTolerance: CGFloat = 10

    static func resolve(
        location: CGPoint,
        draggedID: UUID,
        rowFrames: [UUID: CGRect],
        listFrame: CGRect,
        tolerance: CGFloat = defaultTolerance
    ) -> ProgramQueueDropPreview? {
        let candidates = rowFrames.compactMap { id, frame -> (id: UUID, frame: CGRect)? in
            guard id != draggedID, !frame.isNull, !frame.isEmpty else { return nil }
            return (id, frame)
        }

        guard let legalFrame = legalFrame(listFrame: listFrame, rowFrames: rowFrames),
              legalFrame.insetBy(dx: -tolerance, dy: -tolerance).contains(location)
        else { return nil }

        guard let target = candidates.min(by: { lhs, rhs in
            verticalDistance(from: location.y, to: lhs.frame) < verticalDistance(from: location.y, to: rhs.frame)
        }) else {
            return nil
        }

        return ProgramQueueDropPreview(
            targetID: target.id,
            placement: location.y < target.frame.midY ? .before : .after
        )
    }

    private static func legalFrame(listFrame: CGRect, rowFrames: [UUID: CGRect]) -> CGRect? {
        if !listFrame.isNull, !listFrame.isEmpty {
            return listFrame
        }
        let visibleRows = rowFrames.values.filter { !$0.isNull && !$0.isEmpty }
        return visibleRows.reduce(nil) { partial, frame in
            partial.map { $0.union(frame) } ?? frame
        }
    }

    private static func verticalDistance(from globalY: CGFloat, to frame: CGRect) -> CGFloat {
        if globalY < frame.minY { return frame.minY - globalY }
        if globalY > frame.maxY { return globalY - frame.maxY }
        return 0
    }
}
