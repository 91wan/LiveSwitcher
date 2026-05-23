import CoreGraphics
import Foundation

enum PageInterceptReenableReason: String, Equatable {
    case timeout
    case userInput
}

enum PageInterceptCallbackAction: Equatable {
    case passThrough
    case handleKeyDown
    case reenableTap(reason: PageInterceptReenableReason)
}

enum PageInterceptEventPolicy {
    static func action(for type: CGEventType) -> PageInterceptCallbackAction {
        switch type {
        case .keyDown:
            return .handleKeyDown
        case .tapDisabledByTimeout:
            return .reenableTap(reason: .timeout)
        case .tapDisabledByUserInput:
            return .reenableTap(reason: .userInput)
        default:
            return .passThrough
        }
    }
}

final class PageInterceptRuntime {
    private let lock = NSLock()
    private var eventTap: CFMachPort?

    func updateEventTap(_ tap: CFMachPort?) {
        lock.lock()
        eventTap = tap
        lock.unlock()
    }

    @discardableResult
    func reenableEventTap() -> Bool {
        lock.lock()
        let tap = eventTap
        lock.unlock()

        guard let tap else { return false }
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }
}
