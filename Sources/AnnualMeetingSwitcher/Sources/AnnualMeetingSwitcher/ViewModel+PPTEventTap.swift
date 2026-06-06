import AppKit
import ApplicationServices
import Carbon

@MainActor
extension SwitcherViewModel {
    // MARK: - V25: 翻页拦截器控制

    func startPPTEventTapFromRuntime() {
        if let pageInterceptStartOverride = testHooks.pageInterceptStartOverride {
            if pageInterceptStartOverride() {
                completePPTEventTapStartFromRuntime(detail: "state=enabled,override=true")
                return
            }
            completePPTEventTapStartFailureFromRuntime(reason: "overrideFailed", presentAlert: false)
            return
        }

        guard pageInterceptSideEffectsEnabled else {
            completePPTEventTapStartFromRuntime(detail: "state=enabled,sideEffects=false")
            return
        }

        _ = startPageIntercept()
    }

    func stopPPTEventTapFromRuntime(reason: PPTStopReason) {
        guard pageInterceptSideEffectsEnabled else {
            completePPTEventTapStopFromRuntime(reason: reason, detail: "state=disabled,reason=\(reason.rawValue),sideEffects=false")
            return
        }
        stopPageIntercept(reason: reason)
    }

    private func completePPTEventTapStartFromRuntime(detail: String) {
        let oldPPT = runtime.state.ppt
        dispatchRuntimeFacadeAction(.pptEventTapStarted)
        syncPPTFacadeFromRuntime()
        guard !oldPPT.isEventTapActive, runtime.state.ppt.isEventTapActive else { return }
        LiveSwitcherTelemetry.pageInterceptEnabled()
        recordSupportEvent(kind: .pageInterceptEnabled, detail: detail)
        if let source = consumePendingPPTToggleSource() {
            recordSupportEvent(
                kind: .pptModeChanged,
                detail: "isOn=true,source=\(source.rawValue)"
            )
        }
    }

    private func completePPTEventTapStartFailureFromRuntime(reason: String, presentAlert: Bool) {
        let oldPPT = runtime.state.ppt
        dispatchRuntimeFacadeAction(.pptEventTapFailed(reason: reason))
        syncPPTFacadeFromRuntime()
        guard oldPPT.isRequested || oldPPT.isEventTapActive || currentPendingPPTToggleSource() != nil else { return }
        LiveSwitcherTelemetry.pageInterceptDisabled(reason: reason)
        recordSupportEvent(kind: .pageInterceptDisabled, detail: "reason=\(reason)")
        setPendingPPTToggleSource(nil)
        guard presentAlert else { return }

        Task { @MainActor [weak self] in
            guard let self else { return }
            self.presentAutomationAlert(
                title: "PPT模式无法启动",
                message: "翻页笔接管需要「辅助功能」权限。\n\n请前往：系统设置 → 隐私与安全性 → 辅助功能，找到\"LiveSwitcher\"并打开开关。\n\n设置完成后，重新启动 App 再开启 PPT模式。",
                action: "pageIntercept.\(reason)",
                primaryButton: "打开系统设置",
                secondaryButton: "稍后处理"
            ) {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }

    private func completePPTEventTapStopFromRuntime(reason: PPTStopReason, detail: String? = nil) {
        let oldPPT = runtime.state.ppt
        dispatchRuntimeFacadeAction(.pptEventTapStopped(reason: reason))
        syncPPTFacadeFromRuntime()
        guard oldPPT.isRequested || oldPPT.isEventTapActive || currentPendingPPTToggleSource() != nil else { return }
        LiveSwitcherTelemetry.pageInterceptDisabled(reason: reason.rawValue)
        recordSupportEvent(kind: .pageInterceptDisabled, detail: detail ?? "state=disabled,reason=\(reason.rawValue)")
        if let source = consumePendingPPTToggleSource() {
            recordSupportEvent(
                kind: .pptModeChanged,
                detail: "isOn=false,source=\(source.rawValue)"
            )
        }
    }

    private func startPageIntercept() -> Bool {
        // 权限预检查：无辅助功能权限时提前提示，避免 tapCreate 静默失败
        let axOptions = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        if !AXIsProcessTrustedWithOptions(axOptions) {
            completePPTEventTapStartFailureFromRuntime(reason: "accessibilityPermission", presentAlert: false)
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.presentAutomationAlert(
                    title: "PPT模式需要辅助功能权限",
                    message: "翻页笔接管需要「辅助功能」权限才能工作。\n\n请前往：系统设置 → 隐私与安全性 → 辅助功能，找到\"LiveSwitcher\"并打开开关。\n\n设置完成后，重新启动 App 即可使用 PPT模式。",
                    action: "pageIntercept.accessibilityPermission",
                    primaryButton: "打开系统设置",
                    secondaryButton: "稍后处理"
                ) {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
            return false
        }

        guard currentPageInterceptTapForRuntime() == nil else {
            // 已有 tap，直接 enable
            if let tap = currentPageInterceptTapForRuntime() {
                enableCurrentPageInterceptTapForRuntime()
                updatePageInterceptRuntimeTap(tap)
                completePPTEventTapStartFromRuntime(detail: "state=enabled,existingTap=true")
            }
            return true
        }

        let eventMask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let selfRefcon = Unmanaged.passRetained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: pageInterceptCallback,
            userInfo: selfRefcon
        ) else {
            Unmanaged<SwitcherViewModel>.fromOpaque(selfRefcon).release()
            completePPTEventTapStartFailureFromRuntime(reason: "eventTapCreateFailed", presentAlert: true)
            return false
        }

        guard let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap)
            Unmanaged<SwitcherViewModel>.fromOpaque(selfRefcon).release()
            completePPTEventTapStartFailureFromRuntime(reason: "runLoopSourceCreateFailed", presentAlert: true)
            return false
        }
        CFRunLoopAddSource(CFRunLoopGetCurrent(), src, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        installPageInterceptTapForRuntime(tap: tap, source: src, refcon: selfRefcon)
        updatePageInterceptRuntimeTap(tap)
        completePPTEventTapStartFromRuntime(detail: "state=enabled")
        return true
    }

    private func stopPageIntercept(reason: PPTStopReason = .operatorDisabled) {
        disableCurrentPageInterceptTapForRuntime()
        if let src = currentPageInterceptRunLoopSourceForRuntime() {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), src, .commonModes)
        }
        clearPageInterceptTapForRuntime()
        completePPTEventTapStopFromRuntime(reason: reason)
    }

    nonisolated func reenablePageIntercept(reason: PageInterceptReenableReason) {
        let didReenable = reenablePageInterceptRuntimeTap()
        LiveSwitcherTelemetry.pageInterceptAutoReenabled(reason: reason, didReenable: didReenable)
        Task { @MainActor [weak self] in
            self?.recordSupportEvent(
                kind: .pageInterceptAutoReenabled,
                detail: "reason=\(reason.rawValue),reenabled=\(didReenable)"
            )
        }
    }

    /// 处理拦截到的按键，返回 true 表示吞没（nonisolated 供 C 回调调用）
    nonisolated func handlePageInterceptKey(keyCode: CGKeyCode, flags: CGEventFlags = []) -> Bool {
        // HTML bridge only exposes a lock-protected active flag here; WKWebView stays on MainActor.
        switch keyCode {
        case 121, 124: // PageDown / RightArrow → 下一页
            if HTMLWebViewBridge.shared.hasActiveWebView {
                HTMLWebViewBridge.shared.dispatchArrowKey(isNext: true)
            } else {
                sendPageKeyToWPS(isPageDown: true)
            }
            return true
        case 116, 123: // PageUp / LeftArrow → 上一页
            if HTMLWebViewBridge.shared.hasActiveWebView {
                HTMLWebViewBridge.shared.dispatchArrowKey(isNext: false)
            } else {
                sendPageKeyToWPS(isPageDown: false)
            }
            return true
        default:
            return false
        }
    }

    /// 向后台 WPS 进程注入翻页按键（nonisolated，可在 C 回调中调用）
    nonisolated private func sendPageKeyToWPS(isPageDown: Bool) {
        let direction = isPageDown ? "next" : "previous"
        guard let targetPID = currentWPSProcessIdentifierForPageForwarding() else {
            LiveSwitcherTelemetry.pageInterceptWPSNotRunning(direction: direction)
            Task { @MainActor [weak self] in
                self?.recordSupportEvent(
                    kind: .pageInterceptWPSNotRunning,
                    detail: "direction=\(direction),state=notRunning"
                )
                self?.showAutomationRuntimeNotice(action: "wps.page.\(direction)")
            }
            return
        }
        let keyCode: CGKeyCode = isPageDown ? 121 : 116

        if let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true) {
            keyDown.postToPid(targetPID)
        }
        if let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) {
            keyUp.postToPid(targetPID)
        }
        LiveSwitcherTelemetry.pageInterceptForwardedToWPS(
            direction: direction,
            processIdentifier: targetPID
        )
        Task { @MainActor [weak self] in
            self?.recordSupportEvent(
                kind: .pageInterceptForwardedToWPS,
                detail: "direction=\(direction),target=wps"
            )
        }
    }
}

// MARK: - V25: 翻页拦截 CGEventTap 全局 C 回调

private func pageInterceptCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passUnretained(event) }
    let vm = Unmanaged<SwitcherViewModel>.fromOpaque(refcon).takeUnretainedValue()

    switch PageInterceptEventPolicy.action(for: type) {
    case .passThrough:
        return Unmanaged.passUnretained(event)
    case .reenableTap(let reason):
        vm.reenablePageIntercept(reason: reason)
        return Unmanaged.passUnretained(event)
    case .handleKeyDown:
        break
    }

    let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
    let flags = event.flags
    if vm.handlePageInterceptKey(keyCode: keyCode, flags: flags) {
        return nil  // 吞没事件
    }
    return Unmanaged.passUnretained(event)
}
