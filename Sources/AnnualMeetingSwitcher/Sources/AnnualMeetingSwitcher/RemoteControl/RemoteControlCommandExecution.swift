import Foundation

struct RemoteControlCommandExecutionRecord: Equatable {
    var id: UUID
    var action: String
    var liveModeAction: String
    var isDangerous: Bool

    init(command: RemoteControlAcceptedCommand) {
        id = command.id
        action = command.kind.rawValue
        liveModeAction = command.liveModeAction.rawValue
        isDangerous = command.isDangerous
    }
}

enum RemoteControlCommandExecutionResult: Equatable {
    case executed(RemoteControlCommandExecutionRecord)
    case rejected(RemoteControlCommandRejection)
}
