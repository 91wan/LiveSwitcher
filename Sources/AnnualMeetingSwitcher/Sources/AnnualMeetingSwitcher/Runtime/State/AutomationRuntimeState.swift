import Foundation

struct AutomationRuntimeState: Equatable {
    var notice: AutomationRuntimeNotice?
    var suppressionUntilByAction: [String: Date] = [:]
}
