import Foundation

struct PreflightPopoverLayoutModel: Equatable {
    enum Section: Equatable {
        case header
        case summary
        case filter
        case checks
        case footerActions
    }

    enum FooterAction: Equatable {
        case openCockpit
        case copyReport
        case copySupport
        case saveSupport
    }

    let sections: [Section]
    let headerActions: [FooterAction]
    let footerActions: [FooterAction]

    static func make() -> PreflightPopoverLayoutModel {
        PreflightPopoverLayoutModel(
            sections: [.header, .summary, .filter, .checks, .footerActions],
            headerActions: [],
            footerActions: [.openCockpit, .copyReport, .copySupport, .saveSupport]
        )
    }
}
