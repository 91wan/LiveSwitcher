import AppKit

enum GlobalShortcutPolicy {
    private static let emergencyPanicKeyCode: UInt16 = 11
    private static let mediaToggleKeyCode: UInt16 = 49
    private static let programNumberKeyCodes: Set<UInt16> = [18, 19, 20, 21, 23, 22, 26, 28, 25]
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

    static func shouldPassThroughFocusedResponder(in eventWindow: NSWindow?) -> Bool {
        guard let responder = eventWindow?.firstResponder else { return false }
        return responder is NSText || responder is NSControl
    }

    static func shouldPassThroughFocusedResponder(in eventWindow: NSWindow?, keyCode: UInt16) -> Bool {
        guard let responder = eventWindow?.firstResponder else { return false }
        if responder is NSText { return true }
        if keyCode == mediaToggleKeyCode || programNumberKeyCodes.contains(keyCode) { return false }
        return responder is NSControl
    }
}
