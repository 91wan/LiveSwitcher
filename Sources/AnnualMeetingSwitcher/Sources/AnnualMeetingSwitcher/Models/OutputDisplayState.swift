import Foundation

struct OutputDisplayState: Equatable {
    var currentHTMLURL: URL?
    var isCountdownActive: Bool
    var isTickerActive: Bool
    var isLowerThirdVisible: Bool
    var lowerThirdName: String
    var lowerThirdRole: String
    var lowerThirdOrganization: String
    var isPanicMode: Bool
    var isFadeToBlackActive: Bool
    var cornerLogoPosition: CornerLogoPosition

    static func make(
        currentHTMLURL: URL?,
        isCountdownActive: Bool,
        isTickerActive: Bool,
        isLowerThirdVisible: Bool,
        lowerThirdName: String,
        lowerThirdRole: String,
        lowerThirdOrganization: String,
        isPanicMode: Bool,
        isFadeToBlackActive: Bool,
        cornerLogoPosition: CornerLogoPosition = .topRight
    ) -> OutputDisplayState {
        OutputDisplayState(
            currentHTMLURL: currentHTMLURL,
            isCountdownActive: isCountdownActive,
            isTickerActive: isTickerActive,
            isLowerThirdVisible: isLowerThirdVisible,
            lowerThirdName: lowerThirdName,
            lowerThirdRole: lowerThirdRole,
            lowerThirdOrganization: lowerThirdOrganization,
            isPanicMode: isPanicMode,
            isFadeToBlackActive: isFadeToBlackActive,
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
            lowerThirdRole: viewModel.lowerThirdRole,
            lowerThirdOrganization: viewModel.lowerThirdOrganization,
            isPanicMode: viewModel.isPanicMode,
            isFadeToBlackActive: viewModel.isFadeToBlackActive,
            cornerLogoPosition: viewModel.cornerLogoPosition
        )
    }
}
