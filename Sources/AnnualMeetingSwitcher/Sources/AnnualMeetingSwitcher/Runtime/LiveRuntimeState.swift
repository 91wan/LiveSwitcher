import Foundation

struct LiveRuntimeState: Equatable {
    var mode: ConsoleMode = .setup
    var program = ProgramRuntimeState()
    var programActivation = ProgramActivationRuntimeState()
    var media = MediaRuntimeState()
    var bgm = BGMRuntimeState()
    var audio = AudioRuntimeState()
    var panic = PanicRuntimeState()
    var ppt = PPTRuntimeState()
    var projection = ProjectionRuntimeState()
    var automation = AutomationRuntimeState()
    var presentationQuery = PresentationQueryRuntimeState()
    var preferences = LiveRuntimePreferenceState()
    var support = SupportRuntimeState()
}

struct LiveRuntimeEnvironment: Equatable {
    var now: Date
    var speakerModeDuckedRatio: Float
    var liveAudioFadeDuration: Double
    var bridgeMode: LiveRuntimeBridgeMode

    init(
        now: Date = Date(),
        speakerModeDuckedRatio: Float = AudioRoutingDefaults.speakerModeDuckedRatio,
        liveAudioFadeDuration: Double = AudioRoutingDefaults.liveAudioFadeDuration,
        bridgeMode: LiveRuntimeBridgeMode
    ) {
        self.now = now
        self.speakerModeDuckedRatio = speakerModeDuckedRatio
        self.liveAudioFadeDuration = liveAudioFadeDuration
        self.bridgeMode = bridgeMode
    }

    static func productionAudioOwned(
        now: Date = Date(),
        speakerModeDuckedRatio: Float = AudioRoutingDefaults.speakerModeDuckedRatio,
        liveAudioFadeDuration: Double = AudioRoutingDefaults.liveAudioFadeDuration
    ) -> LiveRuntimeEnvironment {
        LiveRuntimeEnvironment(
            now: now,
            speakerModeDuckedRatio: speakerModeDuckedRatio,
            liveAudioFadeDuration: liveAudioFadeDuration,
            bridgeMode: .audioOwned
        )
    }

    static func productionMediaOwned(
        now: Date = Date(),
        speakerModeDuckedRatio: Float = AudioRoutingDefaults.speakerModeDuckedRatio,
        liveAudioFadeDuration: Double = AudioRoutingDefaults.liveAudioFadeDuration
    ) -> LiveRuntimeEnvironment {
        LiveRuntimeEnvironment(
            now: now,
            speakerModeDuckedRatio: speakerModeDuckedRatio,
            liveAudioFadeDuration: liveAudioFadeDuration,
            bridgeMode: .mediaOwned
        )
    }

    static func productionBGMOwning(
        now: Date = Date(),
        speakerModeDuckedRatio: Float = AudioRoutingDefaults.speakerModeDuckedRatio,
        liveAudioFadeDuration: Double = AudioRoutingDefaults.liveAudioFadeDuration
    ) -> LiveRuntimeEnvironment {
        LiveRuntimeEnvironment(
            now: now,
            speakerModeDuckedRatio: speakerModeDuckedRatio,
            liveAudioFadeDuration: liveAudioFadeDuration,
            bridgeMode: .bgmOwned
        )
    }

    static func productionProjectionOwned(
        now: Date = Date(),
        speakerModeDuckedRatio: Float = AudioRoutingDefaults.speakerModeDuckedRatio,
        liveAudioFadeDuration: Double = AudioRoutingDefaults.liveAudioFadeDuration
    ) -> LiveRuntimeEnvironment {
        LiveRuntimeEnvironment(
            now: now,
            speakerModeDuckedRatio: speakerModeDuckedRatio,
            liveAudioFadeDuration: liveAudioFadeDuration,
            bridgeMode: .projectionOwned
        )
    }

    static func productionPPTOwning(
        now: Date = Date(),
        speakerModeDuckedRatio: Float = AudioRoutingDefaults.speakerModeDuckedRatio,
        liveAudioFadeDuration: Double = AudioRoutingDefaults.liveAudioFadeDuration
    ) -> LiveRuntimeEnvironment {
        LiveRuntimeEnvironment(
            now: now,
            speakerModeDuckedRatio: speakerModeDuckedRatio,
            liveAudioFadeDuration: liveAudioFadeDuration,
            bridgeMode: .pptOwned
        )
    }

    static func productionAutomationNoticeOwning(
        now: Date = Date(),
        speakerModeDuckedRatio: Float = AudioRoutingDefaults.speakerModeDuckedRatio,
        liveAudioFadeDuration: Double = AudioRoutingDefaults.liveAudioFadeDuration
    ) -> LiveRuntimeEnvironment {
        LiveRuntimeEnvironment(
            now: now,
            speakerModeDuckedRatio: speakerModeDuckedRatio,
            liveAudioFadeDuration: liveAudioFadeDuration,
            bridgeMode: .automationNoticeOwned
        )
    }

    static func productionSupportOwning(
        now: Date = Date(),
        speakerModeDuckedRatio: Float = AudioRoutingDefaults.speakerModeDuckedRatio,
        liveAudioFadeDuration: Double = AudioRoutingDefaults.liveAudioFadeDuration
    ) -> LiveRuntimeEnvironment {
        LiveRuntimeEnvironment(
            now: now,
            speakerModeDuckedRatio: speakerModeDuckedRatio,
            liveAudioFadeDuration: liveAudioFadeDuration,
            bridgeMode: .supportOwned
        )
    }

    static func productionAutomationCommandOwning(
        now: Date = Date(),
        speakerModeDuckedRatio: Float = AudioRoutingDefaults.speakerModeDuckedRatio,
        liveAudioFadeDuration: Double = AudioRoutingDefaults.liveAudioFadeDuration
    ) -> LiveRuntimeEnvironment {
        LiveRuntimeEnvironment(
            now: now,
            speakerModeDuckedRatio: speakerModeDuckedRatio,
            liveAudioFadeDuration: liveAudioFadeDuration,
            bridgeMode: .automationCommandOwned
        )
    }

    static func productionPresentationQueryOwning(
        now: Date = Date(),
        speakerModeDuckedRatio: Float = AudioRoutingDefaults.speakerModeDuckedRatio,
        liveAudioFadeDuration: Double = AudioRoutingDefaults.liveAudioFadeDuration
    ) -> LiveRuntimeEnvironment {
        LiveRuntimeEnvironment(
            now: now,
            speakerModeDuckedRatio: speakerModeDuckedRatio,
            liveAudioFadeDuration: liveAudioFadeDuration,
            bridgeMode: .presentationQueryOwned
        )
    }

    static func productionProgramQueueOwning(
        now: Date = Date(),
        speakerModeDuckedRatio: Float = AudioRoutingDefaults.speakerModeDuckedRatio,
        liveAudioFadeDuration: Double = AudioRoutingDefaults.liveAudioFadeDuration
    ) -> LiveRuntimeEnvironment {
        LiveRuntimeEnvironment(
            now: now,
            speakerModeDuckedRatio: speakerModeDuckedRatio,
            liveAudioFadeDuration: liveAudioFadeDuration,
            bridgeMode: .programQueueOwned
        )
    }

    static func productionProgramSelectionOwning(
        now: Date = Date(),
        speakerModeDuckedRatio: Float = AudioRoutingDefaults.speakerModeDuckedRatio,
        liveAudioFadeDuration: Double = AudioRoutingDefaults.liveAudioFadeDuration
    ) -> LiveRuntimeEnvironment {
        LiveRuntimeEnvironment(
            now: now,
            speakerModeDuckedRatio: speakerModeDuckedRatio,
            liveAudioFadeDuration: liveAudioFadeDuration,
            bridgeMode: .programSelectionOwned
        )
    }

    static func productionProgramActivationOwning(
        now: Date = Date(),
        speakerModeDuckedRatio: Float = AudioRoutingDefaults.speakerModeDuckedRatio,
        liveAudioFadeDuration: Double = AudioRoutingDefaults.liveAudioFadeDuration
    ) -> LiveRuntimeEnvironment {
        LiveRuntimeEnvironment(
            now: now,
            speakerModeDuckedRatio: speakerModeDuckedRatio,
            liveAudioFadeDuration: liveAudioFadeDuration,
            bridgeMode: .programActivationOwned
        )
    }

    static func productionPanicOwning(
        now: Date = Date(),
        speakerModeDuckedRatio: Float = AudioRoutingDefaults.speakerModeDuckedRatio,
        liveAudioFadeDuration: Double = AudioRoutingDefaults.liveAudioFadeDuration
    ) -> LiveRuntimeEnvironment {
        LiveRuntimeEnvironment(
            now: now,
            speakerModeDuckedRatio: speakerModeDuckedRatio,
            liveAudioFadeDuration: liveAudioFadeDuration,
            bridgeMode: .panicOwned
        )
    }

    static func fullRuntimeForTests(
        now: Date = Date(),
        speakerModeDuckedRatio: Float = AudioRoutingDefaults.speakerModeDuckedRatio,
        liveAudioFadeDuration: Double = AudioRoutingDefaults.liveAudioFadeDuration
    ) -> LiveRuntimeEnvironment {
        LiveRuntimeEnvironment(
            now: now,
            speakerModeDuckedRatio: speakerModeDuckedRatio,
            liveAudioFadeDuration: liveAudioFadeDuration,
            bridgeMode: .fullRuntime
        )
    }

    static func recordingOnlyForTests(
        now: Date = Date(),
        speakerModeDuckedRatio: Float = AudioRoutingDefaults.speakerModeDuckedRatio,
        liveAudioFadeDuration: Double = AudioRoutingDefaults.liveAudioFadeDuration
    ) -> LiveRuntimeEnvironment {
        LiveRuntimeEnvironment(
            now: now,
            speakerModeDuckedRatio: speakerModeDuckedRatio,
            liveAudioFadeDuration: liveAudioFadeDuration,
            bridgeMode: .recordingOnly
        )
    }
}

struct LiveRuntimeActionLogEntry: Equatable {
    var timestamp: Date
    var actionName: String
    var oldStateSummary: String
    var newStateSummary: String
}
