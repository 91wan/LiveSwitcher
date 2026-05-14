import AppKit

extension SwitcherViewModel {
    func handleSafeBroadcastToggle() {
        if projectionService.hasExternalDisplay {
            // 接了副屏，正常推流
            broadcastSafetyNotice = nil
            isBroadcasting.toggle()
            if isBroadcasting {
                showOutputWindow()
            } else {
                hideOutputWindow()
            }
            LiveSwitcherTelemetry.projectionToggle(isBroadcasting: isBroadcasting)
            recordSupportEvent(kind: .projectionToggle, detail: "isBroadcasting=\(isBroadcasting)")
        } else {
            broadcastSafetyNotice = "未检测到外接屏幕，未开始投射"
            LiveSwitcherTelemetry.projectionFailClosed()
            recordSupportEvent(kind: .projectionFailClosed, detail: "externalDisplay=false")
            // 没有接副屏（只有主屏），弹出防呆警告！
            let alert = NSAlert()
            alert.messageText = "未检测到外接屏幕"
            alert.informativeText = "当前仅有一个屏幕（主监视器）。如果在此屏幕强制推流，将覆盖整个导播台操作界面。建议外接副屏后再点击「投射」！"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "我知道了") // 只有一个退出选项，彻底防呆
            
            _ = alert.runModal()
            // 用户点击知道了，直接返回，不执行任何推流代码
        }
    }
}
