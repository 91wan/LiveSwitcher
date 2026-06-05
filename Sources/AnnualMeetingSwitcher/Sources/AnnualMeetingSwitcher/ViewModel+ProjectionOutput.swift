import AppKit
import SwiftUI

@MainActor
extension SwitcherViewModel {
    // MARK: - 推流控制

    func refreshExternalDisplayAvailability() {
        let isAvailable = externalScreenProvider() != nil
        guard isAvailable != isExternalDisplayAvailable else { return }

        isExternalDisplayAvailable = isAvailable
        if isAvailable {
            dispatchRuntimeFacadeAction(.projectionExternalDisplayAvailable)
        } else {
            dispatchRuntimeFacadeAction(.projectionExternalDisplayUnavailable)
        }
    }

    func setupExternalDisplayObserver() {
        refreshExternalDisplayAvailability()
        cleanupBag.externalDisplayChangeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refreshExternalDisplayAvailability()
            }
        }
    }

    func handleBroadcastToggle() {
        refreshExternalDisplayAvailability()
        let oldProjection = runtime.state.projection
        dispatchRuntimeFacadeAction(.operatorToggledProjection)
        syncProjectionFacadeFromRuntime()
        recordProjectionSupportAfterRuntimeToggle(old: oldProjection, new: runtime.state.projection)
        if oldProjection.isBroadcasting != runtime.state.projection.isBroadcasting {
            LiveSwitcherTelemetry.projectionToggle(isBroadcasting: isBroadcasting)
        }
    }

    func showOutputWindowFromRuntimeProjection() {
        guard let targetScreen = projectionService.targetScreen() else {
            let oldProjection = runtime.state.projection
            dispatchRuntimeFacadeAction(.projectionStartFailed(reason: .noTargetScreen))
            syncProjectionFacadeFromRuntime()
            recordProjectionSupportAfterRuntimeStartFailure(
                old: oldProjection,
                new: runtime.state.projection,
                reason: .noTargetScreen
            )
            return
        }

        if outputWindowController == nil {
            outputWindowController = outputWindowControllerFactory()
            outputWindowController?.onExternalDisplayUnavailable = { [weak self] in
                self?.handleExternalDisplayLost()
            }
            let outputView = AnyView(
                OutputView()
                    .environment(self)
            )
            outputWindowController?.mountAnyView(rootView: outputView)
        }
        outputWindowController?.show(on: targetScreen)
    }

    func hideOutputWindowFromRuntimeProjection() {
        outputWindowController?.hide()
    }

    func handleExternalDisplayLost() {
        guard runtime.state.projection.isBroadcasting else { return }
        let oldProjection = runtime.state.projection
        dispatchRuntimeFacadeAction(.projectionExternalDisplayLost)
        syncProjectionFacadeFromRuntime()
        recordProjectionSupportAfterRuntimeDisplayLost(old: oldProjection, new: runtime.state.projection)
    }

    private func recordProjectionSupportAfterRuntimeToggle(
        old: ProjectionRuntimeState,
        new: ProjectionRuntimeState
    ) {
        if !old.isBroadcasting, new.isBroadcasting {
            recordSupportEvent(kind: .projectionStarted, detail: "isBroadcasting=true")
            recordSupportEvent(kind: .projectionToggle, detail: "isBroadcasting=true")
        } else if old.isBroadcasting, !new.isBroadcasting {
            recordSupportEvent(kind: .projectionStopped, detail: "isBroadcasting=false")
            recordSupportEvent(kind: .projectionToggle, detail: "isBroadcasting=false")
        } else if !old.isBroadcasting,
                  !new.isBroadcasting,
                  new.safetyNotice == "未检测到外接屏幕，未开始投射" {
            LiveSwitcherTelemetry.projectionFailClosed()
            recordSupportEvent(kind: .projectionFailClosed, detail: "externalDisplay=false")
            recordSupportEvent(kind: .projectionStartFailed, detail: "externalDisplay=false")
        }
    }

    private func recordProjectionSupportAfterRuntimeStartFailure(
        old: ProjectionRuntimeState,
        new: ProjectionRuntimeState,
        reason: ProjectionStartFailureReason
    ) {
        guard !old.isBroadcasting,
              !new.isBroadcasting,
              new.safetyNotice == "未检测到外接屏幕，未开始投射"
        else { return }

        LiveSwitcherTelemetry.projectionFailClosed()
        recordSupportEvent(kind: .projectionFailClosed, detail: "reason=\(reason.rawValue)")
        recordSupportEvent(kind: .projectionStartFailed, detail: "reason=\(reason.rawValue)")
    }

    private func recordProjectionSupportAfterRuntimeDisplayLost(
        old: ProjectionRuntimeState,
        new: ProjectionRuntimeState
    ) {
        guard old.isBroadcasting, !new.isBroadcasting else { return }

        LiveSwitcherTelemetry.projectionFailClosed()
        recordSupportEvent(kind: .projectionFailClosed, detail: "externalDisplay=false")
        recordSupportEvent(kind: .projectionLost, detail: "externalDisplay=false")
    }
}
