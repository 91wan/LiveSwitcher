import Foundation

struct OutputDisplayState: Equatable {
    var currentHTMLURL: URL?
    var isCountdownActive: Bool
    var isTickerActive: Bool
    var isLowerThirdVisible: Bool
    var lowerThirdName: String
    var lowerThirdTitle: String
    var isPanicMode: Bool
    var isFadeToBlackActive: Bool
    var cornerLogoURL: URL?
    var cornerLogoPosition: CornerLogoPosition

    static func make(
        currentHTMLURL: URL?,
        isCountdownActive: Bool,
        isTickerActive: Bool,
        isLowerThirdVisible: Bool,
        lowerThirdName: String,
        lowerThirdTitle: String,
        isPanicMode: Bool,
        isFadeToBlackActive: Bool,
        cornerLogoURL: URL? = nil,
        cornerLogoPosition: CornerLogoPosition = .topRight
    ) -> OutputDisplayState {
        OutputDisplayState(
            currentHTMLURL: currentHTMLURL,
            isCountdownActive: isCountdownActive,
            isTickerActive: isTickerActive,
            isLowerThirdVisible: isLowerThirdVisible,
            lowerThirdName: lowerThirdName,
            lowerThirdTitle: lowerThirdTitle,
            isPanicMode: isPanicMode,
            isFadeToBlackActive: isFadeToBlackActive,
            cornerLogoURL: cornerLogoURL,
            cornerLogoPosition: cornerLogoPosition
        )
    }

    @MainActor
    static func make(from viewModel: SwitcherViewModel) -> OutputDisplayState {
        make(
            currentHTMLURL: viewModel.currentHTMLURL,
            isCountdownActive: viewModel.isCountdownActive,
            isTickerActive: viewModel.isTickerActive,
            isLowerThirdVisible: viewModel.isLowerThirdVisible,
            lowerThirdName: viewModel.lowerThirdName,
            lowerThirdTitle: viewModel.lowerThirdTitle,
            isPanicMode: viewModel.isPanicMode,
            isFadeToBlackActive: viewModel.isFadeToBlackActive,
            cornerLogoURL: viewModel.cornerLogoURL,
            cornerLogoPosition: viewModel.cornerLogoPosition
        )
    }
}
