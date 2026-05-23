import Foundation

struct ProgramMonitorInfoBlockModel: Equatable {
    let title: String
    let value: String
    let subtitle: String
    let badgeText: String
    let status: StudioTheme.StatusKind

    var accessibilityLabel: String {
        "\(title): \(value), \(subtitle), \(badgeText)"
    }

    static func current(
        item: ProgramItem?,
        isBroadcasting: Bool,
        isPlaying: Bool,
        isHTMLLoaded: Bool
    ) -> ProgramMonitorInfoBlockModel {
        guard let item else {
            return ProgramMonitorInfoBlockModel(
                title: "Current",
                value: "No Program",
                subtitle: "Standby",
                badgeText: "EMPTY",
                status: .idle
            )
        }

        let subtitle: String
        if isHTMLLoaded {
            subtitle = "HTML is loaded"
        } else if isPlaying {
            subtitle = "Media playing"
        } else {
            subtitle = item.subtitle.uppercased()
        }

        return ProgramMonitorInfoBlockModel(
            title: "Current",
            value: item.title,
            subtitle: subtitle,
            badgeText: isBroadcasting ? "ON AIR" : "PREVIEW",
            status: isBroadcasting ? .live : .idle
        )
    }

    static func next(item: ProgramItem?) -> ProgramMonitorInfoBlockModel {
        guard let item else {
            return ProgramMonitorInfoBlockModel(
                title: "Next",
                value: "None",
                subtitle: "Queue empty",
                badgeText: "EMPTY",
                status: .idle
            )
        }

        return ProgramMonitorInfoBlockModel(
            title: "Next",
            value: item.title,
            subtitle: item.subtitle.uppercased(),
            badgeText: "NEXT",
            status: .ready
        )
    }
}

struct ProgramMonitorStateModel: Equatable {
    let label: String
    let kind: StudioTheme.StatusKind

    static func make(isBroadcasting: Bool, currentItem: ProgramItem?) -> ProgramMonitorStateModel {
        if isBroadcasting {
            return ProgramMonitorStateModel(label: "ON AIR", kind: .live)
        }
        if currentItem != nil {
            return ProgramMonitorStateModel(label: "PREVIEW", kind: .idle)
        }
        return ProgramMonitorStateModel(label: "STANDBY", kind: .idle)
    }
}
