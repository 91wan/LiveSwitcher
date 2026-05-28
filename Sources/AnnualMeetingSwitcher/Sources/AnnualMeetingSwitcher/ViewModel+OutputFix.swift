import AppKit

extension SwitcherViewModel {
    func handleSafeBroadcastToggle() {
        if isBroadcasting {
            broadcastSafetyNotice = nil
            isBroadcasting = false
            hideOutputWindow()
            LiveSwitcherTelemetry.projectionToggle(isBroadcasting: isBroadcasting)
            recordSupportEvent(kind: .projectionToggle, detail: "isBroadcasting=\(isBroadcasting)")
            recordSupportEvent(kind: .projectionStopped, detail: "isBroadcasting=false")
            return
        }

        guard projectionService.hasExternalDisplay else {
            broadcastSafetyNotice = "未检测到外接屏幕，未开始投射"
            LiveSwitcherTelemetry.projectionFailClosed()
            recordSupportEvent(kind: .projectionFailClosed, detail: "externalDisplay=false")
            recordSupportEvent(kind: .projectionStartFailed, detail: "externalDisplay=false")
            let alert = NSAlert()
            alert.messageText = "未检测到外接屏幕"
            alert.informativeText = "当前仅有一个屏幕（主监视器）。如果在此屏幕强制推流，将覆盖整个导播台操作界面。建议外接副屏后再点击「投射」！"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "我知道了")

            _ = alert.runModal()
            return
        }

        broadcastSafetyNotice = nil
        isBroadcasting = true
        showOutputWindow()
        guard isBroadcasting else { return }
        LiveSwitcherTelemetry.projectionToggle(isBroadcasting: isBroadcasting)
        recordSupportEvent(kind: .projectionToggle, detail: "isBroadcasting=\(isBroadcasting)")
        recordSupportEvent(kind: .projectionStarted, detail: "isBroadcasting=true")
    }
}
