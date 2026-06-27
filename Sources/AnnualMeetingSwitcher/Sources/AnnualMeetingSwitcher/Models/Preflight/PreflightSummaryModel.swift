import Foundation

struct LivePreflightSummary: Equatable {
    let status: LivePreflightStatus
    let title: String
    let message: String
    let passCount: Int
    let warnCount: Int
    let failCount: Int

    static func make(from checks: [LivePreflightCheck]) -> LivePreflightSummary {
        let passCount = checks.filter { $0.status == .pass }.count
        let warnCount = checks.filter { $0.status == .warn }.count
        let failCount = checks.filter { $0.status == .fail }.count

        if failCount > 0 {
            return LivePreflightSummary(
                status: .fail,
                title: "未就绪",
                message: "\(failCount) 个阻塞项。投射前请先解决故障项。",
                passCount: passCount,
                warnCount: warnCount,
                failCount: failCount
            )
        }

        if warnCount > 0 {
            return LivePreflightSummary(
                status: .warn,
                title: "需复核",
                message: "\(warnCount) 个警告。直播前请确认现场状态符合预期。",
                passCount: passCount,
                warnCount: warnCount,
                failCount: failCount
            )
        }

        return LivePreflightSummary(
            status: .pass,
            title: "就绪",
            message: "当前运行状态的现场检查全部通过。",
            passCount: passCount,
            warnCount: warnCount,
            failCount: failCount
        )
    }
}
