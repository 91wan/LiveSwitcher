import Foundation

struct SwitcherViewModelTestHooks {
    var pageInterceptStartOverride: (() -> Bool)?
    var scanOpenKeynoteFiles: (() -> [String])?
    var scanKeynoteWindowNames: (() throws -> [String])?
    var presentationQueryService: PresentationQueryService?
    var automationCommandRunner: ((String, String) throws -> Void)?
    var automationCommandDidFinish: (() -> Void)?
    var saveDataDidRun: (() -> Void)?
}
