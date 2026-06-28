struct ViewModelProjectionOutputStore {
    private var outputWindowController: OutputWindowControlling?

    func makeOutputWindowController(factory: () -> OutputWindowControlling) -> OutputWindowControlling {
        factory()
    }

    func currentOutputWindowController() -> OutputWindowControlling? {
        outputWindowController
    }

    mutating func setOutputWindowController(_ controller: OutputWindowControlling?) {
        outputWindowController = controller
    }

    mutating func clearOutputWindowController() {
        outputWindowController = nil
    }
}
