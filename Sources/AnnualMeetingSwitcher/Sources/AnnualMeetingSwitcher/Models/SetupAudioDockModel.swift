import Foundation

struct SetupAudioDockModel: Equatable {
    let masterUserText: String
    let masterEffectiveText: String
    let mediaUserText: String
    let bgmUserText: String
    let mediaEffectiveText: String
    let bgmEffectiveText: String
    let mutedChannelCount: Int

    static func shouldShow(consoleMode: ConsoleMode, selectedTab: MainConsoleTab) -> Bool {
        consoleMode == .setup && selectedTab != .audioMixer
    }

    static func make(
        masterVolume: Double,
        mediaVolume: Double,
        bgmVolume: Double,
        effectiveMediaVolume: Float,
        effectiveBGMVolume: Float,
        isMasterMuted: Bool,
        isMediaMuted: Bool,
        isBGMMuted: Bool
    ) -> SetupAudioDockModel {
        SetupAudioDockModel(
            masterUserText: percent(masterVolume),
            masterEffectiveText: percent(isMasterMuted ? 0 : masterVolume),
            mediaUserText: percent(mediaVolume),
            bgmUserText: percent(bgmVolume),
            mediaEffectiveText: percent(Double(effectiveMediaVolume)),
            bgmEffectiveText: percent(Double(effectiveBGMVolume)),
            mutedChannelCount: [isMasterMuted, isMediaMuted, isBGMMuted].filter { $0 }.count
        )
    }

    private static func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }
}
