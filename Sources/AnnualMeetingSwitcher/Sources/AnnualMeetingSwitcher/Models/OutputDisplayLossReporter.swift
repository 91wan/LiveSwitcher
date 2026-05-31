struct OutputDisplayLossReporter {
    private var hasReportedExternalDisplayUnavailable = false

    mutating func shouldReportDisplayUnavailable(windowIsVisible: Bool = true) -> Bool {
        guard windowIsVisible, !hasReportedExternalDisplayUnavailable else { return false }
        hasReportedExternalDisplayUnavailable = true
        return true
    }

    mutating func resetAfterSuccessfulShow() {
        hasReportedExternalDisplayUnavailable = false
    }
}
