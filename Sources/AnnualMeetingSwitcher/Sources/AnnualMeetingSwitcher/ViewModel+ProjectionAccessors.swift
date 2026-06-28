@MainActor
extension SwitcherViewModel {
    func makeOutputWindowControllerForProjection() -> OutputWindowControlling {
        projectionOutputStore.makeOutputWindowController(factory: outputWindowControllerFactory)
    }

    func currentOutputWindowControllerForProjection() -> OutputWindowControlling? {
        projectionOutputStore.currentOutputWindowController()
    }

    func setOutputWindowControllerForProjection(_ controller: OutputWindowControlling?) {
        projectionOutputStore.setOutputWindowController(controller)
    }

    func clearOutputWindowControllerForProjection() {
        projectionOutputStore.clearOutputWindowController()
    }

    var projectionService: ProjectionService {
        ProjectionService(
            externalScreenProvider: externalScreenProvider,
            hasExternalDisplaySnapshot: isExternalDisplayAvailable
        )
    }

    var hasExternalDisplay: Bool {
        isExternalDisplayAvailable
    }
}
