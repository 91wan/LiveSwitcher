import ApplicationServices

struct ViewModelPageInterceptStore {
    private var pageInterceptEventTap: CFMachPort?
    private var pageInterceptRunLoopSource: CFRunLoopSource?
    private var pageInterceptSelfRefcon: UnsafeMutableRawPointer?
    private var pendingPPTToggleSource: PPTModeToggleSource?

    var isPageInterceptEventTapActive: Bool {
        pageInterceptEventTap != nil
    }

    func currentPageInterceptTap() -> CFMachPort? {
        pageInterceptEventTap
    }

    func currentPageInterceptRunLoopSource() -> CFRunLoopSource? {
        pageInterceptRunLoopSource
    }

    mutating func installPageInterceptTap(
        tap: CFMachPort,
        source: CFRunLoopSource,
        refcon: UnsafeMutableRawPointer
    ) {
        pageInterceptEventTap = tap
        pageInterceptRunLoopSource = source
        pageInterceptSelfRefcon = refcon
    }

    mutating func clearPageInterceptTap() -> UnsafeMutableRawPointer? {
        let refcon = pageInterceptSelfRefcon
        pageInterceptEventTap = nil
        pageInterceptRunLoopSource = nil
        pageInterceptSelfRefcon = nil
        return refcon
    }

    func enableCurrentPageInterceptTap() {
        guard let tap = pageInterceptEventTap else { return }
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func disableCurrentPageInterceptTap() {
        guard let tap = pageInterceptEventTap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
    }

    mutating func setPendingPPTToggleSource(_ source: PPTModeToggleSource?) {
        pendingPPTToggleSource = source
    }

    mutating func consumePendingPPTToggleSource() -> PPTModeToggleSource? {
        let source = pendingPPTToggleSource
        pendingPPTToggleSource = nil
        return source
    }

    func currentPendingPPTToggleSource() -> PPTModeToggleSource? {
        pendingPPTToggleSource
    }
}
