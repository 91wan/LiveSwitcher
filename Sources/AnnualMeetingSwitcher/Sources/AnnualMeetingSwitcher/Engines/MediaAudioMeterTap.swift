import AVFoundation
import MediaToolbox

final class MediaAudioMeterTap: @unchecked Sendable {
    typealias LevelHandler = @Sendable (Float?) -> Void

    private let levelHandler: LevelHandler
    private var tap: MTAudioProcessingTap?
    private var installTask: Task<Void, Never>?

    init(levelHandler: @escaping LevelHandler) {
        self.levelHandler = levelHandler
    }

    deinit {
        installTask?.cancel()
    }

    func install(on item: AVPlayerItem) {
        installTask?.cancel()
        installTask = Task { [weak self, weak item] in
            do {
                guard let tracks = try await item?.asset.loadTracks(withMediaType: .audio),
                      let audioTrack = tracks.first else {
                    self?.levelHandler(nil)
                    return
                }

                await MainActor.run { [weak self, weak item] in
                    guard let self, let item, !Task.isCancelled else { return }
                    self.installAudioMix(on: item, audioTrack: audioTrack)
                }
            } catch {
                self?.levelHandler(nil)
            }
        }
    }

    private func installAudioMix(on item: AVPlayerItem, audioTrack: AVAssetTrack) {
        var callbacks = MTAudioProcessingTapCallbacks(
            version: kMTAudioProcessingTapCallbacksVersion_0,
            clientInfo: Unmanaged.passUnretained(self).toOpaque(),
            init: mediaAudioMeterTapInit,
            finalize: mediaAudioMeterTapFinalize,
            prepare: mediaAudioMeterTapPrepare,
            unprepare: mediaAudioMeterTapUnprepare,
            process: mediaAudioMeterTapProcess
        )

        let (status, createdTap) = createAudioProcessingTap(callbacks: &callbacks)

        guard status == noErr, let createdTap else {
            levelHandler(nil)
            return
        }

        self.tap = createdTap

        let parameters = AVMutableAudioMixInputParameters(track: audioTrack)
        parameters.audioTapProcessor = createdTap

        let mix = AVMutableAudioMix()
        mix.inputParameters = [parameters]
        item.audioMix = mix
    }

    fileprivate func publish(levelDB: Float?) {
        levelHandler(levelDB)
    }
}

private final class MediaAudioMeterTapContext {
    weak var owner: MediaAudioMeterTap?
    var streamDescription: AudioStreamBasicDescription?
    private var lastPublishTime: CFAbsoluteTime = 0

    init(owner: MediaAudioMeterTap) {
        self.owner = owner
    }

    func publish(levelDB: Float?) {
        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastPublishTime >= 1.0 / 30.0 else { return }
        lastPublishTime = now
        owner?.publish(levelDB: levelDB)
    }
}

private func mediaAudioMeterTapInit(
    tap: MTAudioProcessingTap,
    clientInfo: UnsafeMutableRawPointer?,
    tapStorageOut: UnsafeMutablePointer<UnsafeMutableRawPointer?>
) {
    guard let clientInfo else {
        tapStorageOut.pointee = nil
        return
    }

    let owner = Unmanaged<MediaAudioMeterTap>.fromOpaque(clientInfo).takeUnretainedValue()
    tapStorageOut.pointee = Unmanaged.passRetained(MediaAudioMeterTapContext(owner: owner)).toOpaque()
}

private func mediaAudioMeterTapFinalize(tap: MTAudioProcessingTap) {
    let storage = MTAudioProcessingTapGetStorage(tap)
    Unmanaged<MediaAudioMeterTapContext>.fromOpaque(storage).release()
}

private func mediaAudioMeterTapPrepare(
    tap: MTAudioProcessingTap,
    maxFrames: CMItemCount,
    processingFormat: UnsafePointer<AudioStreamBasicDescription>
) {
    context(for: tap)?.streamDescription = processingFormat.pointee
}

private func mediaAudioMeterTapUnprepare(tap: MTAudioProcessingTap) {
    context(for: tap)?.streamDescription = nil
}

private func mediaAudioMeterTapProcess(
    tap: MTAudioProcessingTap,
    numberFrames: CMItemCount,
    flags: MTAudioProcessingTapFlags,
    bufferListInOut: UnsafeMutablePointer<AudioBufferList>,
    numberFramesOut: UnsafeMutablePointer<CMItemCount>,
    flagsOut: UnsafeMutablePointer<MTAudioProcessingTapFlags>
) {
    var timeRange = CMTimeRange()
    let status = MTAudioProcessingTapGetSourceAudio(
        tap,
        numberFrames,
        bufferListInOut,
        flagsOut,
        &timeRange,
        numberFramesOut
    )

    guard status == noErr, numberFramesOut.pointee > 0 else {
        context(for: tap)?.publish(levelDB: nil)
        return
    }

    guard let streamDescription = context(for: tap)?.streamDescription,
          let levelDB = AudioPowerMeter.averagePowerDB(
            bufferList: bufferListInOut,
            streamDescription: streamDescription
          ) else {
        return
    }

    context(for: tap)?.publish(levelDB: levelDB)
}

private func context(for tap: MTAudioProcessingTap) -> MediaAudioMeterTapContext? {
    let storage = MTAudioProcessingTapGetStorage(tap)
    return Unmanaged<MediaAudioMeterTapContext>.fromOpaque(storage).takeUnretainedValue()
}

private func createAudioProcessingTap(
    callbacks: inout MTAudioProcessingTapCallbacks
) -> (status: OSStatus, tap: MTAudioProcessingTap?) {
#if compiler(<6.0)
    var createdTap: Unmanaged<MTAudioProcessingTap>?
    let status = MTAudioProcessingTapCreate(
        kCFAllocatorDefault,
        &callbacks,
        kMTAudioProcessingTapCreationFlag_PostEffects,
        &createdTap
    )
    return (status, createdTap?.takeRetainedValue())
#else
    var createdTap: MTAudioProcessingTap?
    let status = MTAudioProcessingTapCreate(
        kCFAllocatorDefault,
        &callbacks,
        kMTAudioProcessingTapCreationFlag_PostEffects,
        &createdTap
    )
    return (status, createdTap)
#endif
}
