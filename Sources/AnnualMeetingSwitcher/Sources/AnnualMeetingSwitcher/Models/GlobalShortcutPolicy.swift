import AppKit

enum GlobalShortcutPolicy {
    private static let emergencyPanicKeyCode: UInt16 = 11
    private static let programNumberKeyCodes: [UInt16: Int] = [
        18: 0,
        19: 1,
        20: 2,
        21: 3,
        23: 4,
        22: 5,
        26: 6,
        28: 7,
        25: 8
    ]
    private static let nonEmergencyModifierMask: NSEvent.ModifierFlags = [
        .command,
        .option,
        .control,
        .shift
    ]

    static func isEmergencyPanicShortcut(
        keyCode: UInt16,
        modifierFlags: NSEvent.ModifierFlags
    ) -> Bool {
        keyCode == emergencyPanicKeyCode
            && modifierFlags.intersection(nonEmergencyModifierMask) == [.command, .option]
    }

    static func hasNonEmergencyShortcutModifiers(_ modifierFlags: NSEvent.ModifierFlags) -> Bool {
        !modifierFlags.intersection(nonEmergencyModifierMask).isEmpty
    }

    static func shouldHandleEvent(monitorWindow: NSWindow?, eventWindow: NSWindow?) -> Bool {
        guard let monitorWindow, let eventWindow else { return false }
        return monitorWindow === eventWindow
    }

    static func shouldPassThroughFocusedResponder(in eventWindow: NSWindow?, keyCode: UInt16) -> Bool {
        guard let responder = eventWindow?.firstResponder else { return false }
        return responder is NSText || responder is NSControl
    }

    static func programShortcutTargetIndex(for keyCode: UInt16, in items: [ProgramItem]) -> Int? {
        guard let index = programNumberKeyCodes[keyCode],
              items.indices.contains(index),
              !items[index].isAgendaMarker
        else {
            return nil
        }
        return index
    }
}
