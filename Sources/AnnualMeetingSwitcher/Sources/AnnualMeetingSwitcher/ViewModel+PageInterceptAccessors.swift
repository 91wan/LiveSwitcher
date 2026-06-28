import ApplicationServices

@MainActor
extension SwitcherViewModel {
    var isPageInterceptEventTapActiveForRuntimeSnapshot: Bool {
        pageInterceptStore.isPageInterceptEventTapActive
    }

    func currentPageInterceptTapForRuntime() -> CFMachPort? {
        pageInterceptStore.currentPageInterceptTap()
    }

    func currentPageInterceptRunLoopSourceForRuntime() -> CFRunLoopSource? {
        pageInterceptStore.currentPageInterceptRunLoopSource()
    }

    func installPageInterceptTapForRuntime(
        tap: CFMachPort,
        source: CFRunLoopSource,
        refcon: UnsafeMutableRawPointer
    ) {
        pageInterceptStore.installPageInterceptTap(tap: tap, source: source, refcon: refcon)
    }

    func clearPageInterceptTapForRuntime() {
        if let refcon = pageInterceptStore.clearPageInterceptTap() {
            Unmanaged<SwitcherViewModel>.fromOpaque(refcon).release()
        }
        updatePageInterceptRuntimeTap(nil)
    }

    func enableCurrentPageInterceptTapForRuntime() {
        pageInterceptStore.enableCurrentPageInterceptTap()
    }

    func disableCurrentPageInterceptTapForRuntime() {
        pageInterceptStore.disableCurrentPageInterceptTap()
    }

    nonisolated func updatePageInterceptRuntimeTap(_ tap: CFMachPort?) {
        pageInterceptRuntime.updateEventTap(tap)
    }

    nonisolated func reenablePageInterceptRuntimeTap() -> Bool {
        pageInterceptRuntime.reenableEventTap()
    }

    nonisolated func currentWPSProcessIdentifierForPageForwarding() -> pid_t? {
        wpsApplicationMonitor.currentProcessIdentifier
    }

    func setPendingPPTToggleSource(_ source: PPTModeToggleSource?) {
        pageInterceptStore.setPendingPPTToggleSource(source)
    }

    func consumePendingPPTToggleSource() -> PPTModeToggleSource? {
        pageInterceptStore.consumePendingPPTToggleSource()
    }

    func currentPendingPPTToggleSource() -> PPTModeToggleSource? {
        pageInterceptStore.currentPendingPPTToggleSource()
    }
}
