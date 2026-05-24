import Foundation

struct CountPillVisibilityPolicy {
    static func shouldShow(count: Int) -> Bool {
        count > 0
    }
}
