import Foundation

enum ToolbarActionModel {
    enum ActionID: String, CaseIterable {
        case panic
        case preflight
        case help
        case speaker
        case ppt
    }

    struct Action: Identifiable, Equatable {
        let id: ActionID
    }

    static let topActions: [Action] = [
        Action(id: .panic),
        Action(id: .preflight),
        Action(id: .help)
    ]
}
