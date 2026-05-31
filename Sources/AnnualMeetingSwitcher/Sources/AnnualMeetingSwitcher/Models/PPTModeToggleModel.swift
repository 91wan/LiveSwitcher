enum PPTModeToggleSource: String {
    case command
    case toolbar
    case programmatic
}

struct PPTModeToggleModel {
    static func nextState(isEnabled: Bool) -> Bool {
        !isEnabled
    }
}
