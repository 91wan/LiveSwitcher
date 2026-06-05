import Foundation

struct ProgramItem: Identifiable, Equatable {
    let id: UUID
    var title: String
    var subtitle: String
    /// 媒体文件 URL（可选）
    var sourceURL: URL?
    var scheduledStartAt: Date?
    var scheduledDuration: TimeInterval?

    init(
        id: UUID = UUID(),
        title: String,
        subtitle: String = "",
        sourceURL: URL? = nil,
        scheduledStartAt: Date? = nil,
        scheduledDuration: TimeInterval? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.sourceURL = sourceURL
        self.scheduledStartAt = scheduledStartAt
        self.scheduledDuration = scheduledDuration
    }
}
