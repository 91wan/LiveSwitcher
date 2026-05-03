import CoreAudio
import AVFoundation
import Foundation

final class CoreAudioListenerToken {
    let objectID: AudioObjectID
    let address: AudioObjectPropertyAddress
    let queue: DispatchQueue
    let block: AudioObjectPropertyListenerBlock

    init(
        objectID: AudioObjectID,
        address: AudioObjectPropertyAddress,
        queue: DispatchQueue,
        block: @escaping AudioObjectPropertyListenerBlock
    ) {
        self.objectID = objectID
        self.address = address
        self.queue = queue
        self.block = block
    }
}

protocol CoreAudioClient {
    func addPropertyListener(
        objectID: AudioObjectID,
        address: AudioObjectPropertyAddress,
        queue: DispatchQueue,
        block: @escaping AudioObjectPropertyListenerBlock
    ) -> CoreAudioListenerToken?

    func removePropertyListener(_ token: CoreAudioListenerToken)
    func getDefaultOutputDevice() -> AudioDeviceID?
    func getVirtualMainVolume(deviceID: AudioDeviceID) -> Float32?
}

final class CoreAudioSystemClient: CoreAudioClient {
    func addPropertyListener(
        objectID: AudioObjectID,
        address: AudioObjectPropertyAddress,
        queue: DispatchQueue,
        block: @escaping AudioObjectPropertyListenerBlock
    ) -> CoreAudioListenerToken? {
        let token = CoreAudioListenerToken(
            objectID: objectID,
            address: address,
            queue: queue,
            block: block
        )
        var mutableAddress = address
        let status = AudioObjectAddPropertyListenerBlock(
            objectID,
            &mutableAddress,
            queue,
            block
        )
        return status == noErr ? token : nil
    }

    func removePropertyListener(_ token: CoreAudioListenerToken) {
        var mutableAddress = token.address
        AudioObjectRemovePropertyListenerBlock(
            token.objectID,
            &mutableAddress,
            token.queue,
            token.block
        )
    }

    func getDefaultOutputDevice() -> AudioDeviceID? {
        var device = AudioDeviceID(0)
        var propSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &propSize,
            &device
        )
        guard status == noErr, device != kAudioObjectUnknown else { return nil }
        return device
    }

    func getVirtualMainVolume(deviceID: AudioDeviceID) -> Float32? {
        var volume: Float32 = 0
        var propSize = UInt32(MemoryLayout<Float32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            &propSize,
            &volume
        )
        return status == noErr ? volume : nil
    }
}

final class SystemVolumeObserver {
    private let client: CoreAudioClient
    private let queue: DispatchQueue
    private let onVolumeChanged: @MainActor (Double, AudioDeviceID) -> Void

    private var routeListenerToken: CoreAudioListenerToken?
    private var volumeListenerToken: CoreAudioListenerToken?
    private var observedDeviceID: AudioDeviceID = kAudioObjectUnknown
    private var isStarted = false

    init(
        client: CoreAudioClient = CoreAudioSystemClient(),
        queue: DispatchQueue = .main,
        onVolumeChanged: @escaping @MainActor (Double, AudioDeviceID) -> Void
    ) {
        self.client = client
        self.queue = queue
        self.onVolumeChanged = onVolumeChanged
    }

    deinit {
        stop()
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true

        let routeAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        routeListenerToken = client.addPropertyListener(
            objectID: AudioObjectID(kAudioObjectSystemObject),
            address: routeAddress,
            queue: queue
        ) { [weak self] _, _ in
            self?.rebindVolumeListener()
        }

        rebindVolumeListener()
    }

    func stop() {
        if let volumeListenerToken {
            client.removePropertyListener(volumeListenerToken)
            self.volumeListenerToken = nil
        }
        if let routeListenerToken {
            client.removePropertyListener(routeListenerToken)
            self.routeListenerToken = nil
        }
        observedDeviceID = kAudioObjectUnknown
        isStarted = false
    }

    func rebindVolumeListener() {
        guard isStarted else { return }

        if let volumeListenerToken {
            client.removePropertyListener(volumeListenerToken)
            self.volumeListenerToken = nil
            observedDeviceID = kAudioObjectUnknown
        }

        guard let deviceID = client.getDefaultOutputDevice() else { return }

        let volumeAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        volumeListenerToken = client.addPropertyListener(
            objectID: deviceID,
            address: volumeAddress,
            queue: queue
        ) { [weak self] _, _ in
            self?.syncVolumeFromDevice(deviceID)
        }
        observedDeviceID = deviceID
    }

    private func syncVolumeFromDevice(_ deviceID: AudioDeviceID) {
        guard let volume = client.getVirtualMainVolume(deviceID: deviceID) else { return }
        Task { @MainActor [onVolumeChanged] in
            onVolumeChanged(Double(volume), deviceID)
        }
    }
}
