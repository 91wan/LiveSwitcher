import Foundation

enum CornerLogoLoadFailure: Error, Equatable {
    case unsupportedFile
    case decodeFailed

    var displayText: String {
        switch self {
        case .unsupportedFile:
            "不支持的图片文件"
        case .decodeFailed:
            "图片解码失败"
        }
    }
}

enum CornerLogoLoadPhase: Equatable {
    case off
    case loading(candidateURL: URL, requestID: UUID)
    case ready(activeURL: URL)
    case failed(candidateURL: URL?, reason: CornerLogoLoadFailure)

    var candidateURL: URL? {
        switch self {
        case .loading(let candidateURL, _):
            candidateURL
        case .failed(let candidateURL, _):
            candidateURL
        case .off, .ready:
            nil
        }
    }

    var displayText: String {
        switch self {
        case .off:
            "关闭"
        case .loading:
            "加载中"
        case .ready:
            "已就绪"
        case .failed(_, let reason):
            "加载失败：\(reason.displayText)"
        }
    }
}
